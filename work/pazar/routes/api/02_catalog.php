<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;

if (!function_exists('pazar_catalog_hos_fetch_options')) {
    function pazar_catalog_hos_fetch_options(string $path, array $query = []): ?array {
        $base = trim((string) getenv('HOS_API_BASE_URL'));
        if ($base === '') $base = 'http://hos-api:3000';
        $timeout = (int) getenv('HOS_API_TIMEOUT');
        if ($timeout <= 0) $timeout = 2;

        try {
            $resp = Http::timeout($timeout)->acceptJson()->get(rtrim($base, "\\/") . $path, $query);
            if (!$resp->successful()) return null;
            $options = $resp->json('options');
            if (!is_array($options)) return [];
            return array_values(array_filter(array_map(function ($v) {
                return is_string($v) ? trim($v) : '';
            }, $options), function ($v) { return $v !== ''; }));
        } catch (\Throwable $e) {
            return null;
        }
    }
}

// GET /v1/options/cities
// Canonical source: HOS API /v1/options/cities
Route::middleware([\App\Http\Middleware\PersonaScope::class . ':guest'])->get('/v1/options/cities', function () {
    $hos = pazar_catalog_hos_fetch_options('/v1/options/cities');
    if ($hos !== null) return response()->json(['options' => $hos]);

    return response()->json([
        'error' => 'options_source_unavailable',
        'message' => 'HOS options source unavailable'
    ], 503);
});

// GET /v1/options/districts?city=...
// Canonical source: HOS API /v1/options/districts
Route::middleware([\App\Http\Middleware\PersonaScope::class . ':guest'])->get('/v1/options/districts', function (\Illuminate\Http\Request $request) {
    $city = trim((string) $request->query('city', ''));
    if ($city === '') {
        return response()->json([
            'error' => 'missing_city',
            'message' => 'city query parameter is required'
        ], 422);
    }

    $hos = pazar_catalog_hos_fetch_options('/v1/options/districts', ['city' => $city]);
    if ($hos !== null) return response()->json(['options' => $hos]);

    return response()->json([
        'error' => 'options_source_unavailable',
        'message' => 'HOS options source unavailable'
    ], 503);
});

// GET /v1/options/neighborhoods?city=...&district=...
// Canonical source: HOS API /v1/options/neighborhoods
Route::middleware([\App\Http\Middleware\PersonaScope::class . ':guest'])->get('/v1/options/neighborhoods', function (\Illuminate\Http\Request $request) {
    $city = trim((string) $request->query('city', ''));
    $district = trim((string) $request->query('district', ''));
    if ($city === '' || $district === '') {
        return response()->json([
            'error' => 'missing_city_or_district',
            'message' => 'city and district query parameters are required'
        ], 422);
    }

    $hos = pazar_catalog_hos_fetch_options('/v1/options/neighborhoods', ['city' => $city, 'district' => $district]);
    if ($hos !== null) return response()->json(['options' => $hos]);

    return response()->json([
        'error' => 'options_source_unavailable',
        'message' => 'HOS options source unavailable'
    ], 503);
});

// Catalog Spine Endpoints (SPEC Â§6.2, WP-2)
// GET /v1/categories (tree format)
// WP-8: GUEST+ persona (no headers required)
Route::middleware([\App\Http\Middleware\PersonaScope::class . ':guest'])->get('/v1/categories', function () {
    $view = (string) request()->query('view', '');
    $status = strtolower(trim((string) request()->query('status', 'active')));
    if (!in_array($status, ['active', 'inactive', 'all'], true)) {
        $status = 'active';
    }

    // Fetch all categories with parent relationships
    $query = DB::table('categories');
    if ($status !== 'all') {
        $query->where('status', $status);
    }
    $categories = $query
        ->orderBy('sort_order')
        ->get()
        ->map(function ($cat) {
            return [
                'id' => $cat->id,
                // Additive: canonical id for projected views.
                'canonical_category_id' => $cat->id,
                'parent_id' => $cat->parent_id,
                'slug' => $cat->slug,
                // SPEC Canonical Model: title (DB column is `name`)
                'title' => $cat->name,
                // Additive: expose status for clients
                'status' => $cat->status,
            ];
        })
        ->toArray();

    $childCountByParent = [];
    foreach ($categories as $c) {
        $pid = $c['parent_id'] ?? null;
        if (!isset($childCountByParent[$pid])) $childCountByParent[$pid] = 0;
        $childCountByParent[$pid] += 1;
    }
    foreach ($categories as &$c) {
        $id = $c['id'];
        $slug = isset($c['slug']) ? (string) $c['slug'] : '';
        $hasChildren = isset($childCountByParent[$id]) && $childCountByParent[$id] > 0;
        $c['selectable_for_create'] = !$hasChildren || pazar_is_non_leaf_selectable($slug);
    }
    unset($c);

    // Default: canonical DB tree (existing behavior)
    if ($view !== 'menu') {
        // Build tree structure (WP-17 v2: use helper function to avoid redeclare risk)
        $tree = pazar_build_tree($categories);
        return response()->json($tree);
    }

    // view=menu: project a multi-placement menu tree from Trendyol nav edges,
    // while keeping canonical DB ids for selection/search/schema via `canonical_category_id`.
    $nodeBySlug = []; // canonicalSlug => canonicalNode
    $slugById = [];   // canonicalId => canonicalSlug
    foreach ($categories as $c) {
        $slug = (string) ($c['slug'] ?? '');
        if ($slug === '') continue;
        $nodeBySlug[$slug] = $c;
        $slugById[(int) $c['id']] = $slug;
    }

    // Build canonical edges (ensures root reachability even if menu edges are partial)
    $edgesByParentSlug = []; // parentSlug => [childSlug,...] (ordered by canonical sort_order)
    foreach ($categories as $c) {
        $pid = $c['parent_id'] ?? null;
        if ($pid === null) continue;
        $parentSlug = isset($slugById[(int) $pid]) ? (string) $slugById[(int) $pid] : '';
        $childSlug = (string) ($c['slug'] ?? '');
        if ($parentSlug === '' || $childSlug === '') continue;
        if (!isset($edgesByParentSlug[$parentSlug])) $edgesByParentSlug[$parentSlug] = [];
        $edgesByParentSlug[$parentSlug][] = $childSlug;
    }

    // Build wc -> best canonical node map (used to resolve nav placement slugs like `...-ty-c123`)
    $bestNodeByWc = []; // wc => canonicalNode
    $bestGenByWc = [];  // wc => int (gN)
    $nodeByWcGen = [];  // wc => [gen => canonicalNode]
    foreach ($nodeBySlug as $slug => $n) {
        if (!preg_match('/-ty-c(\\d+)$/', $slug, $m)) continue;
        $wc = (string) $m[1];
        $gen = 0;
        if (preg_match('/-g(\\d+)-ty-c\\d+$/', $slug, $gm)) $gen = (int) $gm[1];
        if (!isset($nodeByWcGen[$wc])) $nodeByWcGen[$wc] = [];
        $nodeByWcGen[$wc][$gen] = $n;
        if (!isset($bestNodeByWc[$wc]) || !isset($bestGenByWc[$wc]) || $gen > (int) $bestGenByWc[$wc]) {
            $bestNodeByWc[$wc] = $n;
            $bestGenByWc[$wc] = $gen;
        }
    }

    $extractWcFromWebUrl = function ($webUrl): ?string {
        if (!$webUrl || !is_string($webUrl)) return null;
        $s = (string) $webUrl;
        // Matches: sr?wc=123 or ...&wc=123,456 (pick first)
        if (preg_match('/(?:\\?|&)wc=([0-9,]+)/', $s, $m)) {
            $raw = (string) $m[1];
            $parts = preg_split('/\\s*,\\s*/', $raw);
            if ($parts && isset($parts[0]) && preg_match('/^\\d+$/', (string) $parts[0])) return (string) $parts[0];
        }
        // Matches: some-slug-x-c123
        if (preg_match('/-x-c(\\d+)/', $s, $m)) return (string) $m[1];
        return null;
    };

    $desiredGenForPath = function (array $pathSlugs): int {
        // Heuristic: under "KadÄ±n" prefer g1, under "Erkek" prefer g2.
        foreach ($pathSlugs as $ps) {
            if ((string) $ps === 'service-product-kadin') return 1;
            if ((string) $ps === 'service-product-erkek') return 2;
        }
        return 0;
    };

    $resolveCanonicalByWc = function (string $wc, array $pathSlugs = []) use ($nodeByWcGen, $bestNodeByWc, $desiredGenForPath) {
        // Canonical policy: prefer neutral (non-gendered) category id whenever present.
        // This stabilizes filters/schema (bound to category_id) and prevents g1/g2 leakage across menu DAG paths.
        if (isset($nodeByWcGen[$wc]) && isset($nodeByWcGen[$wc][0])) return $nodeByWcGen[$wc][0];

        $gen = $desiredGenForPath($pathSlugs);
        if ($gen > 0 && isset($nodeByWcGen[$wc]) && isset($nodeByWcGen[$wc][$gen])) return $nodeByWcGen[$wc][$gen];

        return isset($bestNodeByWc[$wc]) ? $bestNodeByWc[$wc] : null;
    };

    // Overlay menu edges (container-accessible file)
    $edgeTitleByChildSlug = []; // childSlug => title
    $edgeWebUrlByChildSlug = []; // childSlug => web_url
    $edgeKindByChildSlug = []; // childSlug => kind
    $edgeWcByChildSlug = []; // childSlug => wc (string)
    $menuEdgesPath = getenv('PAZAR_MENU_EDGES_PATH');
    if (!$menuEdgesPath || !is_string($menuEdgesPath) || $menuEdgesPath === '') {
        $menuEdgesPath = '/var/www/html/catalog/manifests/menu_edges.trendyol.json';
    }
    // Include Trendyol "virtual" nav nodes by default (they may not resolve to a canonical DB category).
    // Opt-out: ?include_virtual=0
    $includeVirtual = ((string) request()->query('include_virtual', '1')) !== '0';

    if ($menuEdgesPath && is_file($menuEdgesPath)) {
        $raw = @file_get_contents($menuEdgesPath);
        $decoded = $raw ? json_decode($raw, true) : null;
        $edges = is_array($decoded) && isset($decoded['edges']) && is_array($decoded['edges']) ? $decoded['edges'] : [];

        $fullRootOverrideServiceProduct = false;
        if (is_array($decoded) && isset($decoded['full_root_override']) && is_array($decoded['full_root_override'])) {
            $fullRootOverrideServiceProduct = !empty($decoded['full_root_override']['service_product']);
        }

        // Group by parent and sort by sort_order
        $grouped = []; // parentSlug => [edge,...]
        foreach ($edges as $e) {
            if (!is_array($e)) continue;
            $k = isset($e['kind']) ? (string) $e['kind'] : '';
            if (!$includeVirtual && $k === 'virtual') continue;
            $p = isset($e['parent_slug']) ? (string) $e['parent_slug'] : '';
            $cslug = isset($e['child_slug']) ? (string) $e['child_slug'] : '';
            if ($p === '' || $cslug === '') continue;
            if (!isset($grouped[$p])) $grouped[$p] = [];
            $grouped[$p][] = $e;
            $edgeKindByChildSlug[$cslug] = $k;
            if (isset($e['title']) && is_string($e['title']) && $e['title'] !== '') {
                $edgeTitleByChildSlug[$cslug] = $e['title'];
            }
            if (isset($e['web_url']) && is_string($e['web_url']) && $e['web_url'] !== '') {
                $edgeWebUrlByChildSlug[$cslug] = $e['web_url'];
            }
            // Deterministic: if the manifest already provides wc, prefer it over parsing web_url.
            if (isset($e['wc']) && is_string($e['wc']) && preg_match('/^\\d+$/', $e['wc'])) {
                $edgeWcByChildSlug[$cslug] = (string) $e['wc'];
            }
        }
        foreach ($grouped as $p => $list) {
            usort($list, function ($a, $b) {
                $ao = isset($a['sort_order']) ? (int) $a['sort_order'] : 0;
                $bo = isset($b['sort_order']) ? (int) $b['sort_order'] : 0;
                if ($ao === $bo) return 0;
                return $ao < $bo ? -1 : 1;
            });
            $kids = [];
            foreach ($list as $e) {
                $kids[] = (string) $e['child_slug'];
            }
            // Dedupe, preserve order
            $seen = [];
            $uniq = [];
            foreach ($kids as $k) {
                if ($k === '' || isset($seen[$k])) continue;
                $seen[$k] = true;
                $uniq[] = $k;
            }

            // Merge: menu edges first (nav ordering), then canonical DB children whose WC
            // is NOT already covered by a nav node. This prevents duplicate entries where
            // both `service-product-nav-p-...-ty-c56` and `service-product-ty-c56` appear.
            $existing = isset($edgesByParentSlug[$p]) && is_array($edgesByParentSlug[$p]) ? $edgesByParentSlug[$p] : [];

            // full_root_override replaces DB children with nav-only children for
            // virtual nav containers (service-product-kadin, ...-erkek, etc.) and
            // nav-placement nodes (-nav-). Canonical DB parents (-ty-c\d+) get MERGE
            // so their deeper DB children (e.g. Mangal under BahÃ§e ÃœrÃ¼nleri) remain navigable.
            $isServiceProductScope = $fullRootOverrideServiceProduct && str_starts_with($p, 'service-product');
            $isCanonicalParent = (bool) preg_match('/-ty-c\\d+$/', $p);
            if ($isServiceProductScope && !empty($uniq) && !$isCanonicalParent) {
                $edgesByParentSlug[$p] = $uniq;
            } else {
                // Build set of WCs already covered by nav edges
                $coveredWcs = [];
                foreach ($uniq as $navSlug) {
                    if (preg_match('/-ty-c(\d+)$/', $navSlug, $wm)) {
                        $coveredWcs[$wm[1]] = true;
                    }
                    // Also check explicit wc from manifest
                    if (isset($edgeWcByChildSlug[$navSlug])) {
                        $coveredWcs[$edgeWcByChildSlug[$navSlug]] = true;
                    }
                }
                // Only add canonical DB children whose WC is not already covered
                $filtered = [];
                foreach ($existing as $dbSlug) {
                    if (in_array($dbSlug, $uniq, true)) continue;
                    $dbWc = null;
                    if (preg_match('/-ty-c(\d+)$/', $dbSlug, $wm)) $dbWc = $wm[1];
                    if ($dbWc !== null && isset($coveredWcs[$dbWc])) continue;
                    $filtered[] = $dbSlug;
                }
                $edgesByParentSlug[$p] = array_merge($uniq, $filtered);
            }
        }
    }

    $menuIdForPath = function (array $pathSlugs): int {
        $s = implode('>', array_values(array_filter(array_map('strval', $pathSlugs))));
        $h = crc32($s);
        if ($h < 0) $h = $h * -1;
        $id = ($h % 2000000000) + 1;
        // Negative ids avoid collisions with DB ids.
        return -1 * (int) $id;
    };

    // Recursively build menu tree starting from canonical roots (parent_id=null).
    // Node identity in this view is menu-path-based (multi-parent safe), while canonical DB id is exposed separately.
    // Gender slugs used to derive gender_context for descendants
    $genderSlugs = [
        'service-product-kadin' => 'kadin',
        'service-product-erkek' => 'erkek',
        'service-product-anne-cocuk' => 'cocuk',
    ];

    $buildMenuBranch = function ($slug, $pathSlugs = [], $guard = []) use (
        &$buildMenuBranch,
        &$edgesByParentSlug,
        &$nodeBySlug,
        &$bestNodeByWc,
        $extractWcFromWebUrl,
        $resolveCanonicalByWc,
        $includeVirtual,
        $edgeTitleByChildSlug,
        $edgeWebUrlByChildSlug,
        $edgeWcByChildSlug,
        $menuIdForPath,
        $genderSlugs
    ) {
        $slug = (string) $slug;
        if ($slug === '') return null;
        // Cycle guard (shouldn't happen, but keep API safe)
        if (isset($guard[$slug])) return null;
        $guard[$slug] = true;

        $canonical = isset($nodeBySlug[$slug]) ? $nodeBySlug[$slug] : null;

        // Resolve nav placement slugs by wc suffix
        if (!$canonical && preg_match('/-ty-c(\\d+)$/', $slug, $m)) {
            $wc = (string) $m[1];
            $resolved = $resolveCanonicalByWc($wc, $pathSlugs);
            if ($resolved) $canonical = $resolved;
        }

        // Resolve virtual nav nodes by parsing wc from web_url (sr?wc=... or ...-x-cNNN)
        if (!$canonical && isset($edgeWebUrlByChildSlug[$slug])) {
            $wc = $extractWcFromWebUrl($edgeWebUrlByChildSlug[$slug]);
            if ($wc) {
                $resolved = $resolveCanonicalByWc($wc, $pathSlugs);
                if ($resolved) $canonical = $resolved;
            }
        }

        // Explicit wc field is the strongest signal â€” always prefer it when present.
        // This bridges nav nodes (e.g. service-product-ev-yasam) to their Trendyol
        // WC category (e.g. service-product-ty-c145704), enabling DB child merge.
        if (isset($edgeWcByChildSlug[$slug])) {
            $wc = (string) $edgeWcByChildSlug[$slug];
            if ($wc !== '') {
                $resolved = $resolveCanonicalByWc($wc, $pathSlugs);
                if ($resolved) $canonical = $resolved;
            }
        }

        $canonicalId = $canonical ? (int) $canonical['id'] : null;
        $title = isset($edgeTitleByChildSlug[$slug]) ? (string) $edgeTitleByChildSlug[$slug] : ($canonical ? (string) $canonical['title'] : $slug);
        $status = $canonical ? (string) $canonical['status'] : 'virtual';
        $selectable = $canonical ? (bool) $canonical['selectable_for_create'] : false;

        // Derive gender_context from ancestor path
        $genderContext = null;
        foreach ($pathSlugs as $ps) {
            if (isset($genderSlugs[$ps])) { $genderContext = $genderSlugs[$ps]; break; }
        }

        $node = [
            'id' => $menuIdForPath(!empty($pathSlugs) ? $pathSlugs : [$slug]),
            'canonical_category_id' => $canonicalId,
            'slug' => $slug,
            'title' => $title,
            'status' => $status,
            'selectable_for_create' => $selectable,
            'gender_context' => $genderContext,
        ];

        $children = [];
        $childSlugs = isset($edgesByParentSlug[$slug]) ? $edgesByParentSlug[$slug] : [];
        $isNavPlacement = str_contains($slug, '-nav-');
        $isGenderPath = false;
        $isChildPath = false;
        foreach ($pathSlugs as $ps) {
            if ($ps === 'service-product-kadin' || $ps === 'service-product-erkek') {
                $isGenderPath = true;
                break;
            }
            if ($ps === 'service-product-anne-cocuk') {
                $isChildPath = true;
                break;
            }
        }
        // KadÄ±n/Erkek: block nav-placement BRANCH nodes (curated children only)
        // Anne & Ã‡ocuk: block ALL nav-placement nodes (prevent adult content under children)
        $blockDbMerge = $isNavPlacement && (
            (!empty($childSlugs) && $isGenderPath) || $isChildPath
        );
        if (!$blockDbMerge && $canonical && isset($canonical['slug']) && is_string($canonical['slug'])) {
            $canonicalSlug = (string) $canonical['slug'];
            if ($canonicalSlug !== '' && $canonicalSlug !== $slug && isset($edgesByParentSlug[$canonicalSlug]) && is_array($edgesByParentSlug[$canonicalSlug])) {
                $coveredWcs = [];
                foreach ($childSlugs as $existingSlug) {
                    if (preg_match('/-ty-c(\d+)$/', $existingSlug, $wm)) $coveredWcs[$wm[1]] = true;
                    if (isset($edgeWcByChildSlug[$existingSlug])) $coveredWcs[$edgeWcByChildSlug[$existingSlug]] = true;
                }
                foreach ($edgesByParentSlug[$canonicalSlug] as $dbSlug) {
                    if (in_array($dbSlug, $childSlugs, true)) continue;
                    $dbWc = null;
                    if (preg_match('/-ty-c(\d+)$/', $dbSlug, $wm)) $dbWc = $wm[1];
                    if ($dbWc !== null && isset($coveredWcs[$dbWc])) continue;
                    $childSlugs[] = $dbSlug;
                }
            }
        }
        foreach ($childSlugs as $cs) {
            $child = $buildMenuBranch($cs, array_merge(!empty($pathSlugs) ? $pathSlugs : [$slug], [$cs]), $guard);
            if ($child) $children[] = $child;
        }
        if (!empty($children)) $node['children'] = $children;
        return $node;
    };

    // Canonical roots as entrypoints (keeps existing API shape stable)
    $roots = [];
    foreach ($categories as $c) {
        if (($c['parent_id'] ?? null) !== null) continue;
        $slug = (string) ($c['slug'] ?? '');
        if ($slug === '') continue;
        $built = $buildMenuBranch($slug, [$slug], []);
        if ($built) $roots[] = $built;
    }

    return response()->json($roots);
});

// GET /v1/categories/{id}/children
// Returns direct DB children of a category (the sidebar sub-categories).
// Deterministic: pure parent-child from SSOT, independent of menu_edges.
Route::middleware([\App\Http\Middleware\PersonaScope::class . ':guest'])->get('/v1/categories/{id}/children', function ($id) {
    $category = DB::table('categories')->where('id', $id)->where('status', 'active')->first();
    if (!$category) {
        return response()->json([
            'error' => 'category_not_found',
            'message' => "Category with id {$id} not found",
        ], 404);
    }

    $directChildren = DB::table('categories')
        ->where('parent_id', $id)
        ->where('status', 'active')
        ->orderBy('sort_order')
        ->orderBy('id')
        ->get();

    $childIds = $directChildren->pluck('id')->all();
    $parentIdsWithGrandchildren = [];
    if (!empty($childIds)) {
        $parentIdsWithGrandchildren = DB::table('categories')
            ->whereIn('parent_id', $childIds)
            ->where('status', 'active')
            ->distinct()
            ->pluck('parent_id')
            ->map(fn ($v) => (int) $v)
            ->all();
    }
    $hasChildrenSet = array_flip($parentIdsWithGrandchildren);

    $children = $directChildren->map(function ($c) use ($hasChildrenSet) {
            return [
                'id' => $c->id,
                'slug' => $c->slug,
                'title' => $c->name,
                'status' => $c->status,
                'has_children' => isset($hasChildrenSet[(int) $c->id]),
            ];
        })
        ->values()
        ->all();

    return response()->json([
        'parent_id' => (int) $id,
        'parent_slug' => $category->slug,
        'children' => $children,
    ]);
});

// GET /v1/categories/{id}/filter-schema
// WP-8: GUEST+ persona (no headers required)
Route::middleware([\App\Http\Middleware\PersonaScope::class . ':guest'])->get('/v1/categories/{id}/filter-schema', function ($id) {
    
    // Verify category exists
    $category = DB::table('categories')->where('id', $id)->first();
    if (!$category) {
        return response()->json([
            'error' => 'category_not_found',
            'message' => "Category with id {$id} not found"
        ], 404);
    }
    
    $selectFields = [
        'category_filter_schema.id',
        'category_filter_schema.attribute_key',
        'category_filter_schema.status',
        'category_filter_schema.sort_order',
        'category_filter_schema.ui_component',
        'category_filter_schema.required',
        'category_filter_schema.filter_mode',
        'category_filter_schema.rules_json',
        'category_filter_schema.applies_to_transaction_modes',
        'attributes.value_type',
        'attributes.unit',
        'attributes.description'
    ];
    
    $schema = DB::table('category_filter_schema')
        ->join('attributes', 'category_filter_schema.attribute_key', '=', 'attributes.key')
        ->where('category_filter_schema.category_id', $id)
        ->where('category_filter_schema.status', 'active')
        ->orderBy('category_filter_schema.sort_order')
        ->select($selectFields)
        ->get()
        ->map(function ($item) {
            $result = [
                'attribute_key' => $item->attribute_key,
                // WP-FINAL: Canonical key alias (catalog defines filter keys; clients should use this)
                'key' => $item->attribute_key,
                // WP-69: UI-friendly label field (additive; does not change meaning)
                'label' => $item->description ? $item->description : $item->attribute_key,
                'value_type' => $item->value_type,
                'unit' => $item->unit,
                'description' => $item->description,
                'status' => $item->status,
                'sort_order' => $item->sort_order,
            ];
            
            $result['ui_component'] = $item->ui_component;
            $result['ui_type'] = $item->ui_component;
            $result['required'] = (bool) $item->required;
            $result['filter_mode'] = $item->filter_mode;
            $result['rules'] = (object) [];

            $type = 'text';
            if ($item->ui_component === 'select' || $item->value_type === 'enum') {
                $type = 'select';
            } elseif ($item->value_type === 'boolean') {
                $type = 'boolean';
            } elseif ($item->filter_mode === 'range') {
                $type = 'range';
            } elseif ($item->value_type === 'number') {
                $type = 'number';
            }
            $result['type'] = $type;

            if ($item->rules_json) {
                $rules = json_decode($item->rules_json, true);
                if ($rules) {
                    if (isset($rules['options']) && is_array($rules['options'])) {
                        $mapped = array_map(function ($opt) {
                            if (is_array($opt)) {
                                if (isset($opt['value'])) return (string) $opt['value'];
                                if (isset($opt['label'])) return (string) $opt['label'];
                                if (isset($opt['key'])) return (string) $opt['key'];
                                if (isset($opt['id'])) return (string) $opt['id'];
                                return null;
                            }
                            if (is_object($opt)) {
                                if (isset($opt->value)) return (string) $opt->value;
                                if (isset($opt->label)) return (string) $opt->label;
                                if (isset($opt->key)) return (string) $opt->key;
                                if (isset($opt->id)) return (string) $opt->id;
                                return null;
                            }
                            if (is_string($opt) || is_numeric($opt)) return (string) $opt;
                            return null;
                        }, $rules['options']);
                        $rules['options'] = array_values(array_filter($mapped, function ($s) {
                            return $s !== null && $s !== '';
                        }));
                    }
                    $result['rules'] = $rules;
                }
            }

            $applies = null;
            if (isset($item->applies_to_transaction_modes) && $item->applies_to_transaction_modes) {
                $decoded = json_decode($item->applies_to_transaction_modes, true);
                if (is_array($decoded)) {
                    $applies = array_values(array_filter(array_map('strval', $decoded)));
                }
            }
            $result['applies_to_transaction_modes'] = $applies;
            
            return $result;
        })
        ->toArray();

    // Deterministic schema overrides (rollback-safe):
    // - Fix root-level vehicle_brand contamination for motosiklet (use child brand nodes as source)
    // - Remove misleading vehicle_brand at ticari-arac root (root children are types, not brands)
    //
    // One-click disable: set env PAZAR_FILTER_SCHEMA_BRAND_OVERRIDE=0
    // Use getenv() instead of env() to avoid config/runtime differences.
    $enableBrandOverride = getenv('PAZAR_FILTER_SCHEMA_BRAND_OVERRIDE') !== '0';
    $slug = isset($category->slug) ? (string) $category->slug : '';
    if ($enableBrandOverride && $slug !== '') {
        if ($slug === 'motosiklet') {
            // Optional debug: /filter-schema?__debug=1 will include exception message on failure.
            $debug = (string) request()->query('__debug', '') === '1';
            try {
                $childBrandTitlesRaw = DB::table('categories')
                    ->where('parent_id', (int) $id)
                    ->where('status', 'active')
                    ->orderBy('name')
                    ->pluck('name')
                    ->toArray();

                $childBrandTitles = array_values(array_filter(array_map(function ($t) {
                    return (string) $t;
                }, is_array($childBrandTitlesRaw) ? $childBrandTitlesRaw : []), function ($t) {
                    return is_string($t) && $t !== '';
                }));

                if (!empty($childBrandTitles)) {
                    $schema = array_map(function ($f) use ($childBrandTitles) {
                        if (!is_array($f)) return $f;
                        $k = isset($f['attribute_key']) ? (string) $f['attribute_key'] : (isset($f['key']) ? (string) $f['key'] : '');
                        if ($k !== 'vehicle_brand') return $f;
                        if (!isset($f['rules']) || !is_array($f['rules'])) $f['rules'] = [];
                        $f['rules']['options'] = $childBrandTitles;
                        return $f;
                    }, $schema);
                }
            } catch (\Throwable $e) {
                if ($debug) {
                    return response()->json([
                        'error' => 'schema_override_exception',
                        'message' => $e->getMessage(),
                    ], 500);
                }
                // Fail-open: never break the endpoint if override fails.
            }
        } elseif ($slug === 'ticari-arac') {
            // Remove root brand filter to avoid misleading UX. Leaf brand pages handle models/brands correctly.
            $schema = array_values(array_filter($schema, function ($f) {
                if (!is_array($f)) return true;
                $k = isset($f['attribute_key']) ? (string) $f['attribute_key'] : (isset($f['key']) ? (string) $f['key'] : '');
                return $k !== 'vehicle_brand';
            }));
        }
    }
    
    return response()->json([
        'category_id' => (int) $id,
        'category_slug' => $category->slug,
        'filters' => $schema
    ]);
});

// GET /v1/categories/{id}/intent-schema
// Purpose: drive "2nd column" (offer/intents) without encoding it in categories
// WP-8: GUEST+ persona (no headers required)
Route::middleware([\App\Http\Middleware\PersonaScope::class . ':guest'])->get('/v1/categories/{id}/intent-schema', function ($id) {
    $category = DB::table('categories')->where('id', $id)->first();
    if (!$category) {
        return response()->json([
            'error' => 'category_not_found',
            'message' => "Category with id {$id} not found"
        ], 404);
    }

    $schema = pazar_category_intent_schema((int) $id);
    // Additive: include the requested category slug for client convenience
    $schema['category_slug'] = (string) $category->slug;    return response()->json($schema);
});

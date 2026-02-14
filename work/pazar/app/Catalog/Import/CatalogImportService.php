<?php

namespace App\Catalog\Import;

use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Schema;
use JsonException;
use RuntimeException;

final class CatalogImportService
{
    /**
     * Importer rules:
     * - Deterministic reads
     * - Fail-fast validations
     * - Clean-install apply is "clean DB only" + transactional (ya hep ya hiç)
     *
     * Note:
     * - `apply()` = clean install path (requires clean DB)
     * - `syncApply()` = in-place sync path (no clean DB requirement; no deletes)
     */

    private const ALLOWED_CATEGORY_STATUS = ['active', 'inactive'];
    private const ALLOWED_UI_COMPONENTS = ['text', 'number', 'select', 'boolean'];
    private const ALLOWED_FILTER_MODES = ['exact', 'range'];
    private const ALLOWED_TX_MODES = ['sale', 'rental', 'reservation'];

    /**
     * Cache for referenced manifest files (rules_ref).
     *
     * @var array<string,mixed>
     */
    private array $refCache = [];

    public function __construct(
        private readonly string $basePath
    ) {
    }

    public static function fromDefaultPath(): self
    {
        // Back-compat default: repo manifests.
        // V2: allow external manifests root via env var to avoid repo bloat.
        // - Container path example: /var/www/html/catalog/manifests
        // - Windows host path is only relevant for volume mounts (not for PHP inside container)
        $p = env('CATALOG_MANIFESTS_PATH', '');
        $p = is_string($p) ? trim($p) : '';
        if ($p === '') {
            $p = base_path('catalog/manifests');
            // If legacy path is missing (repo cleaned), fall back to minimal in-repo CI/dev set.
            // This keeps local non-docker flows (e.g. XAMPP) working without extra env config.
            if (!File::exists($p)) {
                $fallback = base_path('catalog/manifests_ci');
                if (File::exists($fallback)) {
                    $p = $fallback;
                }
            }
        } else {
            // If relative, resolve from base_path()
            $isWindowsAbs = (bool) preg_match('/^[a-zA-Z]:[\\\\\\/]/', $p) || strncmp($p, '\\\\', 2) === 0;
            $isUnixAbs = isset($p[0]) && $p[0] === '/';
            if (!$isWindowsAbs && !$isUnixAbs) {
                $p = base_path($p);
            }
        }

        return new self($p);
    }

    /**
     * Create importer from an explicit manifests root path (CLI-friendly).
     * If relative, it's resolved from Laravel base_path().
     */
    public static function fromPath(string $path): self
    {
        $p = trim($path);
        if ($p === '') {
            return self::fromDefaultPath();
        }
        $isWindowsAbs = (bool) preg_match('/^[a-zA-Z]:[\\\\\\/]/', $p) || strncmp($p, '\\\\', 2) === 0;
        $isUnixAbs = isset($p[0]) && $p[0] === '/';
        if (!$isWindowsAbs && !$isUnixAbs) {
            $p = base_path($p);
        }
        return new self($p);
    }

    /**
     * @return array{
     *   meta: array<string,mixed>,
     *   attributes: list<array{key:string,value_type:string,unit:mixed,description:mixed}>,
     *   categories: list<array{slug:string,parent_slug:mixed,title:string,status:string,sort_order:int}>,
     *   schemaBlocks: list<array{schema_version:int,category_slugs:list<string>,fields:list<array<string,mixed>>}>
     * }
     */
    public function loadManifests(): array
    {
        $meta = $this->readJsonFile($this->path('manifest.meta.json'), expectedType: 'object');
        $attributes = $this->readJsonFile($this->path('attributes.json'), expectedType: 'array');
        $aliases = [];
        $aliasesPath = $this->path('aliases.json');
        if (File::exists($aliasesPath)) {
            $aliases = $this->readJsonFile($aliasesPath, expectedType: 'object');
        }

        $categories = [];
        foreach ($this->listJsonFiles($this->path('categories')) as $file) {
            $data = $this->readJsonFile($file, expectedType: 'array');
            foreach ($data as $row) {
                $categories[] = $row;
            }
        }

        $schemaBlocks = [];
        foreach ($this->listJsonFiles($this->path('schema')) as $file) {
            $data = $this->readJsonFile($file, expectedType: 'any');
            foreach ($this->normalizeSchemaBlocks($data, $file) as $block) {
                $schemaBlocks[] = $block;
            }
        }

        return [
            'meta' => $meta,
            'attributes' => $attributes,
            'aliases' => $aliases,
            'categories' => $categories,
            'schemaBlocks' => $schemaBlocks,
        ];
    }

    public function validateOrFail(array $m): void
    {
        // --- meta ---
        if (!is_array($m['meta'] ?? null)) {
            throw new RuntimeException('manifest.meta.json must be a JSON object.');
        }
        if (($m['meta']['manifest_version'] ?? null) !== 1) {
            throw new RuntimeException('manifest.meta.json.manifest_version must be 1 for V1.');
        }

        // --- attributes ---
        $attributes = $m['attributes'] ?? null;
        if (!is_array($attributes)) {
            throw new RuntimeException('attributes.json must be a JSON array.');
        }
        $attributeKeys = [];
        foreach ($attributes as $idx => $row) {
            if (!is_array($row)) {
                throw new RuntimeException("attributes.json[$idx] must be an object.");
            }
            $key = $row['key'] ?? null;
            if (!is_string($key) || $key === '') {
                throw new RuntimeException("attributes.json[$idx].key must be a non-empty string.");
            }
            if (isset($attributeKeys[$key])) {
                throw new RuntimeException("Duplicate attribute key in attributes.json: {$key}");
            }
            $attributeKeys[$key] = true;

            $valueType = $row['value_type'] ?? null;
            if (!is_string($valueType) || $valueType === '') {
                throw new RuntimeException("attributes.json[$idx].value_type must be a non-empty string.");
            }
            if (array_key_exists('unit', $row) && !is_null($row['unit']) && !is_string($row['unit'])) {
                throw new RuntimeException("attributes.json[$idx].unit must be string|null.");
            }
            if (array_key_exists('description', $row) && !is_null($row['description']) && !is_string($row['description'])) {
                throw new RuntimeException("attributes.json[$idx].description must be string|null.");
            }
        }

        // --- categories ---
        $categories = $m['categories'] ?? null;
        if (!is_array($categories)) {
            throw new RuntimeException('categories manifests must decode into a flat list of objects.');
        }

        $bySlug = [];
        foreach ($categories as $idx => $row) {
            if (!is_array($row)) {
                throw new RuntimeException("categories[$idx] must be an object.");
            }

            $slug = $row['slug'] ?? null;
            if (!is_string($slug) || $slug === '') {
                throw new RuntimeException("categories[$idx].slug must be a non-empty string.");
            }
            if (isset($bySlug[$slug])) {
                throw new RuntimeException("Duplicate category slug across manifests: {$slug}");
            }

            $parentSlug = $row['parent_slug'] ?? null;
            if (!is_null($parentSlug) && (!is_string($parentSlug) || $parentSlug === '')) {
                throw new RuntimeException("categories[$idx].parent_slug must be string|null.");
            }

            $title = $row['title'] ?? null;
            if (!is_string($title) || $title === '') {
                throw new RuntimeException("categories[$idx].title must be a non-empty string.");
            }

            $status = $row['status'] ?? null;
            if (!is_string($status) || !in_array($status, self::ALLOWED_CATEGORY_STATUS, true)) {
                $allowed = implode('|', self::ALLOWED_CATEGORY_STATUS);
                throw new RuntimeException("categories[$idx].status must be one of {$allowed}.");
            }

            $sortOrder = $row['sort_order'] ?? null;
            if (!is_int($sortOrder)) {
                throw new RuntimeException("categories[$idx].sort_order must be an integer.");
            }

            $bySlug[$slug] = [
                'slug' => $slug,
                'parent_slug' => $parentSlug,
                'title' => $title,
                'status' => $status,
                'sort_order' => $sortOrder,
            ];
        }

        // --- aliases (V2) ---
        $aliases = $m['aliases'] ?? null;
        if (!is_null($aliases)) {
            if (!is_array($aliases)) {
                throw new RuntimeException('aliases.json must be a JSON object (map old_slug -> new_slug).');
            }
            $usedNew = [];
            foreach ($aliases as $old => $new) {
                if (!is_string($old) || $old === '') {
                    throw new RuntimeException('aliases.json keys must be non-empty strings (old_slug).');
                }
                if (!is_string($new) || $new === '') {
                    throw new RuntimeException("aliases.json[$old] must be a non-empty string (new_slug).");
                }
                if ($old === $new) {
                    throw new RuntimeException("aliases.json contains self-mapping: {$old} -> {$new}");
                }
                // New slug must exist in manifest categories to avoid dangling renames.
                if (!isset($bySlug[$new])) {
                    throw new RuntimeException("aliases.json maps to unknown new_slug not in categories manifests: {$new}");
                }
                // Avoid ambiguity: manifest must not contain the old slug (rename-only contract).
                if (isset($bySlug[$old])) {
                    throw new RuntimeException("aliases.json old_slug must not be present in categories manifests: {$old}");
                }
                if (isset($usedNew[$new])) {
                    throw new RuntimeException("aliases.json maps multiple old slugs to the same new_slug: {$new}");
                }
                $usedNew[$new] = true;
            }
        }

        // Parent existence check (fail-fast)
        foreach ($bySlug as $slug => $row) {
            $parent = $row['parent_slug'];
            if ($parent !== null && !isset($bySlug[$parent])) {
                throw new RuntimeException("Category {$slug} references missing parent_slug: {$parent}");
            }
        }

        // Cycle detection (parent chain)
        foreach ($bySlug as $slug => $row) {
            $seen = [];
            $cur = $slug;
            while (true) {
                if (isset($seen[$cur])) {
                    throw new RuntimeException("Category cycle detected via slug: {$cur}");
                }
                $seen[$cur] = true;
                $parent = $bySlug[$cur]['parent_slug'] ?? null;
                if ($parent === null) {
                    break;
                }
                $cur = $parent;
            }
        }

        // --- schema blocks + fields ---
        $schemaBlocks = $m['schemaBlocks'] ?? null;
        if (!is_array($schemaBlocks)) {
            throw new RuntimeException('schema manifests must decode into a list of blocks.');
        }

        $schemaPairs = []; // category_slug|attribute_key => true (collision FAIL)
        foreach ($schemaBlocks as $bIdx => $block) {
            if (!is_array($block)) {
                throw new RuntimeException("schemaBlocks[$bIdx] must be an object.");
            }
            $schemaVersion = $block['schema_version'] ?? null;
            if (!is_int($schemaVersion)) {
                throw new RuntimeException("schemaBlocks[$bIdx].schema_version must be an integer.");
            }

            $categorySlugs = $block['category_slugs'] ?? null;
            if (!is_array($categorySlugs)) {
                throw new RuntimeException("schemaBlocks[$bIdx].category_slugs must be an array.");
            }
            foreach ($categorySlugs as $sIdx => $slug) {
                if (!is_string($slug) || $slug === '') {
                    throw new RuntimeException("schemaBlocks[$bIdx].category_slugs[$sIdx] must be a non-empty string.");
                }
                if (!isset($bySlug[$slug])) {
                    throw new RuntimeException("schemaBlocks[$bIdx] references unknown category_slug: {$slug}");
                }
            }

            $fields = $block['fields'] ?? null;
            if (!is_array($fields)) {
                throw new RuntimeException("schemaBlocks[$bIdx].fields must be an array.");
            }

            foreach ($fields as $fIdx => $field) {
                if (!is_array($field)) {
                    throw new RuntimeException("schemaBlocks[$bIdx].fields[$fIdx] must be an object.");
                }

                $attributeKey = $field['attribute_key'] ?? null;
                if (!is_string($attributeKey) || $attributeKey === '') {
                    throw new RuntimeException("schemaBlocks[$bIdx].fields[$fIdx].attribute_key must be a non-empty string.");
                }
                if (!isset($attributeKeys[$attributeKey])) {
                    throw new RuntimeException("schemaBlocks[$bIdx].fields[$fIdx] references missing attribute_key in attributes.json: {$attributeKey}");
                }

                $uiComponent = $field['ui_component'] ?? null;
                if (!is_string($uiComponent) || !in_array($uiComponent, self::ALLOWED_UI_COMPONENTS, true)) {
                    $allowed = implode('|', self::ALLOWED_UI_COMPONENTS);
                    throw new RuntimeException("schemaBlocks[$bIdx].fields[$fIdx].ui_component must be one of {$allowed}.");
                }

                $required = $field['required'] ?? null;
                if (!is_bool($required)) {
                    throw new RuntimeException("schemaBlocks[$bIdx].fields[$fIdx].required must be boolean.");
                }

                $filterMode = $field['filter_mode'] ?? null;
                if (!is_string($filterMode) || !in_array($filterMode, self::ALLOWED_FILTER_MODES, true)) {
                    $allowed = implode('|', self::ALLOWED_FILTER_MODES);
                    throw new RuntimeException("schemaBlocks[$bIdx].fields[$fIdx].filter_mode must be one of {$allowed}.");
                }

                $rules = $field['rules'] ?? null;
                if (!is_null($rules) && !is_array($rules)) {
                    throw new RuntimeException("schemaBlocks[$bIdx].fields[$fIdx].rules must be object|null.");
                }
                $rulesRef = $field['rules_ref'] ?? null;
                if (!is_null($rulesRef) && !is_string($rulesRef) && !is_array($rulesRef)) {
                    throw new RuntimeException("schemaBlocks[$bIdx].fields[$fIdx].rules_ref must be string|object|null.");
                }
                if (!is_null($rulesRef) && !is_null($rules)) {
                    throw new RuntimeException("schemaBlocks[$bIdx].fields[$fIdx] cannot define both rules and rules_ref.");
                }

                // Validate referenced rules deterministically (fail-fast).
                if (!is_null($rulesRef)) {
                    try {
                        $resolved = $this->resolveRulesFromField($field, categorySlug: (string)($categorySlugs[0] ?? ''));
                    } catch (RuntimeException $e) {
                        throw new RuntimeException("schemaBlocks[$bIdx].fields[$fIdx].rules_ref invalid: " . $e->getMessage());
                    }
                    if ($uiComponent === 'select') {
                        if (!is_array($resolved) || !array_key_exists('options', $resolved) || !is_array($resolved['options'])) {
                            throw new RuntimeException("schemaBlocks[$bIdx].fields[$fIdx] select requires resolved rules.options array.");
                        }
                        foreach ($resolved['options'] as $oIdx => $opt) {
                            if (!is_string($opt)) {
                                throw new RuntimeException("schemaBlocks[$bIdx].fields[$fIdx] resolved rules.options[$oIdx] must be a string.");
                            }
                        }
                    }
                }
                if ($uiComponent === 'select' && is_array($rules) && array_key_exists('options', $rules)) {
                    if (!is_array($rules['options'])) {
                        throw new RuntimeException("schemaBlocks[$bIdx].fields[$fIdx].rules.options must be an array.");
                    }
                    foreach ($rules['options'] as $oIdx => $opt) {
                        if (!is_string($opt)) {
                            throw new RuntimeException("schemaBlocks[$bIdx].fields[$fIdx].rules.options[$oIdx] must be a string.");
                        }
                    }
                }
                if (is_array($rules)) {
                    foreach (['min', 'max'] as $bound) {
                        if (array_key_exists($bound, $rules) && !is_null($rules[$bound]) && !is_int($rules[$bound]) && !is_float($rules[$bound])) {
                            throw new RuntimeException("schemaBlocks[$bIdx].fields[$fIdx].rules.{$bound} must be numeric|null.");
                        }
                    }
                }

                $sortOrder = $field['sort_order'] ?? null;
                if (!is_int($sortOrder)) {
                    throw new RuntimeException("schemaBlocks[$bIdx].fields[$fIdx].sort_order must be an integer.");
                }

                $applies = $field['applies_to_transaction_modes'] ?? null;
                if (!is_null($applies) && !is_array($applies)) {
                    throw new RuntimeException("schemaBlocks[$bIdx].fields[$fIdx].applies_to_transaction_modes must be array|null.");
                }
                if (is_array($applies)) {
                    if (count($applies) !== count(array_unique($applies))) {
                        throw new RuntimeException("schemaBlocks[$bIdx].fields[$fIdx].applies_to_transaction_modes must not contain duplicates.");
                    }
                    foreach ($applies as $mIdx => $mode) {
                        if (!is_string($mode) || !in_array($mode, self::ALLOWED_TX_MODES, true)) {
                            $allowed = implode('|', self::ALLOWED_TX_MODES);
                            throw new RuntimeException("schemaBlocks[$bIdx].fields[$fIdx].applies_to_transaction_modes[$mIdx] must be one of {$allowed}.");
                        }
                    }
                }

                // collision check is per category_slug + attribute_key
                foreach ($categorySlugs as $slug) {
                    $k = $slug . '|' . $attributeKey;
                    if (isset($schemaPairs[$k])) {
                        throw new RuntimeException("Duplicate schema definition for (category_slug, attribute_key): ({$slug}, {$attributeKey})");
                    }
                    $schemaPairs[$k] = true;
                }
            }
        }
    }

    /**
     * @return array{
     *   categories: array{insert:int,update:int,total:int},
     *   attributes: array{insert:int,update:int,total:int},
     *   schema: array{insert:int,update:int,total:int},
     *   samples: array{categories:list<array<string,mixed>>, attributes:list<array<string,mixed>>, schema:list<array<string,mixed>>}
     * }
     */
    public function plan(array $m): array
    {
        $now = CarbonImmutable::now()->toIso8601String();

        $categories = $this->normalizeCategories($m['categories'] ?? []);
        $attributes = $this->normalizeAttributes($m['attributes'] ?? []);
        $schemaRows = $this->expandSchemaRows($m['schemaBlocks'] ?? []);

        $catExisting = $this->safeExistingKeys('categories', 'slug');
        $attrExisting = $this->safeExistingKeys('attributes', 'key');
        $schemaExisting = $this->safeExistingSchemaPairs();

        $catInsert = 0;
        $catUpdate = 0;
        foreach ($categories as $c) {
            if (!isset($catExisting[$c['slug']])) {
                $catInsert++;
            } else {
                $catUpdate++;
            }
        }

        $attrInsert = 0;
        $attrUpdate = 0;
        foreach ($attributes as $a) {
            if (!isset($attrExisting[$a['key']])) {
                $attrInsert++;
            } else {
                $attrUpdate++;
            }
        }

        $schemaInsert = 0;
        $schemaUpdate = 0;
        foreach ($schemaRows as $r) {
            $k = $r['category_slug'] . '|' . $r['attribute_key'];
            if (!isset($schemaExisting[$k])) {
                $schemaInsert++;
            } else {
                $schemaUpdate++;
            }
        }

        return [
            'categories' => ['insert' => $catInsert, 'update' => $catUpdate, 'total' => count($categories)],
            'attributes' => ['insert' => $attrInsert, 'update' => $attrUpdate, 'total' => count($attributes)],
            'schema' => ['insert' => $schemaInsert, 'update' => $schemaUpdate, 'total' => count($schemaRows)],
            'samples' => [
                'categories' => array_slice($categories, 0, 20),
                'attributes' => array_slice($attributes, 0, 20),
                'schema' => array_slice($schemaRows, 0, 20),
            ],
            'generated_at' => $now,
        ];
    }

    public function apply(array $m): void
    {
        $this->assertDbReadyForApply();
        $this->assertDbIsCleanForV1Apply();

        $categories = $this->normalizeCategories($m['categories'] ?? []);
        $attributes = $this->normalizeAttributes($m['attributes'] ?? []);
        $schemaRows = $this->expandSchemaRows($m['schemaBlocks'] ?? []);
        $slugToStatus = [];
        foreach ($categories as $c) {
            $slugToStatus[$c['slug']] = $c['status'];
        }

        DB::transaction(function () use ($categories, $attributes, $schemaRows, $slugToStatus) {
            $now = CarbonImmutable::now()->toDateTimeString();

            // 1) categories (deterministic, parent-first insert)
            $slugToId = $this->insertCategoriesParentFirst($categories, $now);

            // 2) attributes
            if (count($attributes) > 0) {
                $rows = [];
                foreach ($attributes as $a) {
                    $rows[] = [
                        'key' => $a['key'],
                        'value_type' => $a['value_type'],
                        'unit' => $a['unit'],
                        'description' => $a['description'],
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
                $this->insertChunked('attributes', $rows);
            }

            // 3) schema
            if (count($schemaRows) > 0) {
                $rows = [];
                foreach ($schemaRows as $r) {
                    $categoryId = $slugToId[$r['category_slug']] ?? null;
                    if ($categoryId === null) {
                        // Should be impossible due to validations, but keep it fail-fast.
                        throw new RuntimeException("Schema references unknown category_slug at apply time: {$r['category_slug']}");
                    }
                    $catStatus = $slugToStatus[$r['category_slug']] ?? 'active';
                    $rows[] = [
                        'category_id' => $categoryId,
                        'attribute_key' => $r['attribute_key'],
                        'ui_component' => $r['ui_component'],
                        'required' => $r['required'],
                        'filter_mode' => $r['filter_mode'],
                        'rules_json' => $r['rules_json'],
                        'applies_to_transaction_modes' => $r['applies_to_transaction_modes'],
                        'status' => $catStatus === 'active' ? 'active' : 'inactive',
                        'sort_order' => $r['sort_order'],
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }
                $this->insertChunked('category_filter_schema', $rows);
            }
        }, attempts: 1);
    }

    /**
     * V2: In-place sync (no clean DB requirement).
     * - Inserts missing categories/attributes/schema.
     * - Updates existing rows to match manifest.
     * - Marks schema rows missing from manifest as inactive (no deletes).
     */
    public function syncApply(array $m): void
    {
        $this->assertDbReadyForApply();

        $categories = $this->normalizeCategories($m['categories'] ?? []);
        $attributes = $this->normalizeAttributes($m['attributes'] ?? []);
        $schemaRows = $this->expandSchemaRows($m['schemaBlocks'] ?? []);
        $aliases = is_array($m['aliases'] ?? null) ? $m['aliases'] : [];
        $slugToStatus = [];
        foreach ($categories as $c) {
            $slugToStatus[$c['slug']] = $c['status'];
        }

        DB::transaction(function () use ($categories, $attributes, $schemaRows, $aliases, $slugToStatus) {
            $now = CarbonImmutable::now()->toDateTimeString();

            // 0) Apply alias renames (slug updates) best-effort, fail-fast on conflicts.
            $this->applyCategoryAliasesOrFail($aliases);

            // 1) categories: insert missing + update fields/parent_id
            $slugToIdExisting = DB::table('categories')->pluck('id', 'slug')->toArray();
            $slugToIdExisting = array_map(fn ($v) => (int)$v, $slugToIdExisting);

            $missing = [];
            foreach ($categories as $c) {
                if (!isset($slugToIdExisting[$c['slug']])) {
                    $missing[] = $c;
                }
            }

            $slugToId = $this->insertCategoriesParentFirst($missing, $now, $slugToIdExisting);

            // Update all manifest categories deterministically (parent_id/name/status/sort_order)
            foreach ($categories as $c) {
                $parentId = null;
                if ($c['parent_slug'] !== null) {
                    $parentId = $slugToId[$c['parent_slug']] ?? null;
                    if ($parentId === null) {
                        throw new RuntimeException("Unable to resolve parent_slug during sync: {$c['slug']} -> {$c['parent_slug']}");
                    }
                }
                DB::table('categories')
                    ->where('slug', $c['slug'])
                    ->update([
                        'parent_id' => $parentId,
                        'name' => $c['title'],
                        'status' => $c['status'],
                        'sort_order' => $c['sort_order'],
                        'updated_at' => $now,
                    ]);
            }

            // 2) attributes: insert missing + update existing (by key)
            $attrExisting = DB::table('attributes')->pluck('key')->map(fn ($k) => (string)$k)->all();
            $attrExistingSet = [];
            foreach ($attrExisting as $k) { $attrExistingSet[$k] = true; }

            $attrInserts = [];
            foreach ($attributes as $a) {
                if (!isset($attrExistingSet[$a['key']])) {
                    $attrInserts[] = [
                        'key' => $a['key'],
                        'value_type' => $a['value_type'],
                        'unit' => $a['unit'],
                        'description' => $a['description'],
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                } else {
                    DB::table('attributes')->where('key', $a['key'])->update([
                        'value_type' => $a['value_type'],
                        'unit' => $a['unit'],
                        'description' => $a['description'],
                        'updated_at' => $now,
                    ]);
                }
            }
            if (count($attrInserts) > 0) {
                $this->insertChunked('attributes', $attrInserts);
            }

            // 3) schema: insert missing + update existing (by category_id + attribute_key), no deletes.
            $schemaExisting = DB::table('category_filter_schema')
                ->select(['category_id', 'attribute_key'])
                ->get()
                ->map(function ($r) {
                    return ((int)$r->category_id) . '|' . ((string)$r->attribute_key);
                })
                ->all();
            $schemaExistingSet = [];
            foreach ($schemaExisting as $k) { $schemaExistingSet[$k] = true; }

            $schemaInserts = [];
            $manifestPairsByCategoryId = []; // category_id => set(pairKey)
            foreach ($schemaRows as $r) {
                $categoryId = $slugToId[$r['category_slug']] ?? null;
                if ($categoryId === null) {
                    throw new RuntimeException("Schema references unknown category_slug at sync time: {$r['category_slug']}");
                }
                $pairKey = $categoryId . '|' . $r['attribute_key'];
                $manifestPairsByCategoryId[$categoryId][$pairKey] = true;
                $catStatus = $slugToStatus[$r['category_slug']] ?? 'active';
                $schemaStatus = $catStatus === 'active' ? 'active' : 'inactive';

                if (!isset($schemaExistingSet[$pairKey])) {
                    $schemaInserts[] = [
                        'category_id' => $categoryId,
                        'attribute_key' => $r['attribute_key'],
                        'ui_component' => $r['ui_component'],
                        'required' => $r['required'],
                        'filter_mode' => $r['filter_mode'],
                        'rules_json' => $r['rules_json'],
                        'applies_to_transaction_modes' => $r['applies_to_transaction_modes'],
                        'status' => $schemaStatus,
                        'sort_order' => $r['sort_order'],
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                } else {
                    DB::table('category_filter_schema')
                        ->where('category_id', $categoryId)
                        ->where('attribute_key', $r['attribute_key'])
                        ->update([
                            'ui_component' => $r['ui_component'],
                            'required' => $r['required'],
                            'filter_mode' => $r['filter_mode'],
                            'rules_json' => $r['rules_json'],
                            'applies_to_transaction_modes' => $r['applies_to_transaction_modes'],
                            'status' => $schemaStatus,
                            'sort_order' => $r['sort_order'],
                            'updated_at' => $now,
                        ]);
                }
            }
            if (count($schemaInserts) > 0) {
                $this->insertChunked('category_filter_schema', $schemaInserts);
            }

            // Mark schema rows that are not in manifest as inactive (for categories in manifest only)
            $categoryIdsInManifest = array_values(array_unique(array_map(fn ($c) => $slugToId[$c['slug']] ?? null, $categories)));
            $categoryIdsInManifest = array_values(array_filter($categoryIdsInManifest, fn ($v) => !is_null($v)));
            foreach ($categoryIdsInManifest as $cid) {
                $pairsSet = $manifestPairsByCategoryId[$cid] ?? [];
                $rows = DB::table('category_filter_schema')
                    ->where('category_id', $cid)
                    ->where('status', 'active')
                    ->select(['attribute_key'])
                    ->get();
                foreach ($rows as $row) {
                    $k = $cid . '|' . ((string)$row->attribute_key);
                    if (!isset($pairsSet[$k])) {
                        DB::table('category_filter_schema')
                            ->where('category_id', $cid)
                            ->where('attribute_key', (string)$row->attribute_key)
                            ->update(['status' => 'inactive', 'updated_at' => $now]);
                    }
                }
            }

            // 4) Trendyol gendered categories normalization (deterministic):
            // If any gendered variant (service-product-gN-ty-cWC) is active, keep the neutral category
            // (service-product-ty-cWC) active as the single canonical "ID gate" for schema/filters.
            //
            // Rationale: schema is bound to category_id; when neutral is inactive/missing, menu projection
            // falls back to g1/g2 and causes multiplicity + missing filters on non-gendered paths.
            $this->normalizeTrendyolNeutralCategoriesFromGendered(now: $now);
        }, attempts: 1);
    }

    /**
     * Deterministic backfill:
     * - Insert missing neutral categories for active gendered variants.
     * - Activate neutral categories when any gendered variant is active.
     * - Activate schema rows for those neutral categories (schema is bound to category_id).
     *
     * Important: This runs *after* manifest-driven sync steps so it "wins" even if legacy manifests
     * accidentally mark neutral categories/schema inactive.
     */
    private function normalizeTrendyolNeutralCategoriesFromGendered(string $now): void
    {
        // 1) Insert missing neutral categories (rare; prefer g1 over g2 deterministically).
        DB::statement(
            "with g as (
                select
                    parent_id,
                    slug,
                    name,
                    vertical,
                    sort_order,
                    substring(slug from '-ty-c([0-9]+)$') as wc,
                    case
                        when slug ~ '^service-product-g1-' then 1
                        when slug ~ '^service-product-g2-' then 2
                        else 9
                    end as pri
                from categories
                where status='active'
                  and slug ~ '^service-product-g[0-9]+-ty-c[0-9]+$'
            ),
            pick as (
                select distinct on (wc)
                    wc,
                    parent_id,
                    slug,
                    name,
                    vertical,
                    sort_order
                from g
                order by wc, pri asc
            ),
            ins as (
                select
                    regexp_replace(slug, '^service-product-g[0-9]+-', 'service-product-') as neutral_slug,
                    parent_id,
                    name,
                    vertical,
                    sort_order
                from pick
            )
            insert into categories (parent_id, slug, name, vertical, status, sort_order, created_at, updated_at)
            select
                ins.parent_id,
                ins.neutral_slug,
                ins.name,
                ins.vertical,
                'active',
                ins.sort_order,
                ?,
                ?
            from ins
            where not exists (select 1 from categories n where n.slug = ins.neutral_slug)",
            [$now, $now]
        );

        // 2) Activate neutral categories when a gendered variant is active.
        DB::statement(
            "with active_gendered as (
                select distinct regexp_replace(slug, '^service-product-g[0-9]+-', 'service-product-') as neutral_slug
                from categories
                where status='active'
                  and slug ~ '^service-product-g[0-9]+-ty-c[0-9]+$'
            )
            update categories n
            set status='active', updated_at=?
            from active_gendered ag
            where n.slug = ag.neutral_slug
              and n.status <> 'active'",
            [$now]
        );

        // 3) Activate schema rows for those neutral categories (filters must work on the neutral id).
        DB::statement(
            "with active_gendered as (
                select distinct regexp_replace(slug, '^service-product-g[0-9]+-', 'service-product-') as neutral_slug
                from categories
                where status='active'
                  and slug ~ '^service-product-g[0-9]+-ty-c[0-9]+$'
            ),
            neutral_ids as (
                select id
                from categories c
                join active_gendered ag on ag.neutral_slug = c.slug
                where c.status='active'
            )
            update category_filter_schema s
            set status='active', updated_at=?
            from neutral_ids n
            where s.category_id = n.id
              and s.status <> 'active'",
            [$now]
        );

        // 4) Backfill missing neutral schema rows from the best active gendered variant (prefer g1, else g2).
        // Some neutral categories may have been historically kept inactive and ended up with 0 schema rows.
        // This ensures neutral is a complete "filter gate" without requiring manifest changes.
        DB::statement(
            "with g as (
                select
                    id as g_id,
                    substring(slug from '-ty-c([0-9]+)$') as wc,
                    case
                        when slug ~ '^service-product-g1-' then 1
                        when slug ~ '^service-product-g2-' then 2
                        else 9
                    end as pri
                from categories
                where status='active'
                  and slug ~ '^service-product-g[0-9]+-ty-c[0-9]+$'
            ),
            pick as (
                select distinct on (wc)
                    wc,
                    g_id
                from g
                order by wc, pri asc
            ),
            neutral as (
                select
                    id as n_id,
                    substring(slug from '-ty-c([0-9]+)$') as wc
                from categories
                where status='active'
                  and slug ~ '^service-product-ty-c[0-9]+$'
            ),
            pairs as (
                select
                    n.n_id as category_id,
                    s.attribute_key,
                    s.ui_component,
                    s.required,
                    s.filter_mode,
                    s.rules_json,
                    s.applies_to_transaction_modes,
                    s.sort_order
                from pick p
                join neutral n on n.wc = p.wc
                join category_filter_schema s on s.category_id = p.g_id
            )
            insert into category_filter_schema (
                category_id,
                attribute_key,
                ui_component,
                required,
                filter_mode,
                rules_json,
                applies_to_transaction_modes,
                status,
                sort_order,
                created_at,
                updated_at
            )
            select
                p.category_id,
                p.attribute_key,
                p.ui_component,
                p.required,
                p.filter_mode,
                p.rules_json,
                p.applies_to_transaction_modes,
                'active',
                p.sort_order,
                ?,
                ?
            from pairs p
            where not exists (
                select 1 from category_filter_schema x
                where x.category_id = p.category_id
                  and x.attribute_key = p.attribute_key
            )",
            [$now, $now]
        );
    }

    // -----------------------
    // Internal helpers
    // -----------------------

    private function path(string $relative): string
    {
        return rtrim($this->basePath, "\\/") . DIRECTORY_SEPARATOR . ltrim($relative, "\\/");
    }

    /**
     * @return list<string>
     */
    private function listJsonFiles(string $dir): array
    {
        if (!File::exists($dir)) {
            return [];
        }
        $paths = File::glob(rtrim($dir, "\\/") . DIRECTORY_SEPARATOR . '*.json') ?: [];
        sort($paths, SORT_STRING);
        return array_values($paths);
    }

    /**
     * @return mixed
     */
    private function readJsonFile(string $path, string $expectedType): mixed
    {
        if (!File::exists($path)) {
            throw new RuntimeException("Manifest file not found: {$path}");
        }
        try {
            $raw = File::get($path);
            $data = json_decode($raw, true, 512, JSON_THROW_ON_ERROR);
        } catch (JsonException $e) {
            throw new RuntimeException("Invalid JSON in {$path}: " . $e->getMessage());
        }

        if ($expectedType === 'object' && !is_array($data)) {
            throw new RuntimeException("Expected JSON object in {$path}");
        }
        if ($expectedType === 'array' && !is_array($data)) {
            throw new RuntimeException("Expected JSON array in {$path}");
        }

        return $data;
    }

    /**
     * Accept either:
     * - single schema block object (schema_version, category_slugs, fields)
     * - array of schema block objects
     *
     * @return list<array{schema_version:int,category_slugs:list<string>,fields:list<array<string,mixed>>}>
     */
    private function normalizeSchemaBlocks(mixed $data, string $file): array
    {
        if (is_array($data) && array_key_exists('schema_version', $data)) {
            return [$data];
        }
        if (is_array($data)) {
            // Assume list of blocks
            foreach ($data as $idx => $row) {
                if (!is_array($row)) {
                    throw new RuntimeException("Schema file {$file} must be an object or array of objects (invalid item at index {$idx}).");
                }
            }
            return $data;
        }
        throw new RuntimeException("Schema file {$file} must be a JSON object or array.");
    }

    /**
     * @param list<array<string,mixed>> $categories
     * @return list<array{slug:string,parent_slug:?string,title:string,status:string,sort_order:int}>
     */
    private function normalizeCategories(array $categories): array
    {
        $out = [];
        foreach ($categories as $row) {
            if (!is_array($row)) {
                continue;
            }
            $out[] = [
                'slug' => (string)($row['slug'] ?? ''),
                'parent_slug' => $row['parent_slug'] === null ? null : (string)$row['parent_slug'],
                'title' => (string)($row['title'] ?? ''),
                'status' => (string)($row['status'] ?? ''),
                'sort_order' => (int)($row['sort_order'] ?? 0),
            ];
        }
        usort($out, fn ($a, $b) => strcmp($a['slug'], $b['slug'])); // deterministic sample ordering
        return $out;
    }

    /**
     * @param list<array<string,mixed>> $attributes
     * @return list<array{key:string,value_type:string,unit:?string,description:?string}>
     */
    private function normalizeAttributes(array $attributes): array
    {
        $out = [];
        foreach ($attributes as $row) {
            if (!is_array($row)) {
                continue;
            }
            $out[] = [
                'key' => (string)($row['key'] ?? ''),
                'value_type' => (string)($row['value_type'] ?? ''),
                'unit' => array_key_exists('unit', $row) ? ($row['unit'] === null ? null : (string)$row['unit']) : null,
                'description' => array_key_exists('description', $row) ? ($row['description'] === null ? null : (string)$row['description']) : null,
            ];
        }
        usort($out, fn ($a, $b) => strcmp($a['key'], $b['key']));
        return $out;
    }

    /**
     * Expand schema blocks into flat rows keyed by (category_slug, attribute_key).
     *
     * @param list<array{schema_version:int,category_slugs:list<string>,fields:list<array<string,mixed>>}> $schemaBlocks
     * @return list<array{
     *   category_slug:string,
     *   attribute_key:string,
     *   ui_component:string,
     *   required:bool,
     *   filter_mode:string,
     *   rules_json:?string,
     *   sort_order:int,
     *   applies_to_transaction_modes:?string
     * }>
     */
    private function expandSchemaRows(array $schemaBlocks): array
    {
        $rows = [];
        foreach ($schemaBlocks as $block) {
            $categorySlugs = $block['category_slugs'] ?? [];
            $fields = $block['fields'] ?? [];
            foreach ($categorySlugs as $categorySlug) {
                foreach ($fields as $f) {
                    $rules = $this->resolveRulesFromField(is_array($f) ? $f : [], (string)$categorySlug);
                    $applies = $f['applies_to_transaction_modes'] ?? null;

                    $rows[] = [
                        'category_slug' => (string)$categorySlug,
                        'attribute_key' => (string)($f['attribute_key'] ?? ''),
                        'ui_component' => (string)($f['ui_component'] ?? ''),
                        'required' => (bool)($f['required'] ?? false),
                        'filter_mode' => (string)($f['filter_mode'] ?? ''),
                        'rules_json' => is_null($rules) ? null : json_encode($rules, JSON_UNESCAPED_UNICODE),
                        'sort_order' => (int)($f['sort_order'] ?? 0),
                        'applies_to_transaction_modes' => is_null($applies) ? null : json_encode($applies, JSON_UNESCAPED_UNICODE),
                    ];
                }
            }
        }

        usort($rows, function ($a, $b) {
            $c = strcmp($a['category_slug'], $b['category_slug']);
            if ($c !== 0) {
                return $c;
            }
            return strcmp($a['attribute_key'], $b['attribute_key']);
        });

        return $rows;
    }

    /**
     * Resolve schema rules from either inline `rules` or external `rules_ref`.
     *
     * Supported `rules_ref`:
     * - string: path to a JSON array of strings (relative to manifests root); treated as select options list.
     * - object:
     *   - { "type": "options_file", "path": "<file.json>" }
     *   - { "type": "vehicle_models_by_brand_slug", "path": "vehicle-otomobil-models.autoevolution.tr.json" }
     *
     * @param array<string,mixed> $field
     * @return array<string,mixed>|null
     */
    private function resolveRulesFromField(array $field, string $categorySlug): ?array
    {
        $rules = $field['rules'] ?? null;
        if (!is_null($rules)) {
            return is_array($rules) ? $rules : null;
        }

        $rulesRef = $field['rules_ref'] ?? null;
        if (is_null($rulesRef)) {
            return null;
        }

        // String shorthand: options list file
        if (is_string($rulesRef)) {
            return ['options' => $this->readOptionsListFromManifestRef($rulesRef)];
        }

        if (!is_array($rulesRef)) {
            throw new RuntimeException('rules_ref must be string|object.');
        }

        $type = $rulesRef['type'] ?? null;
        $path = $rulesRef['path'] ?? null;
        if (!is_string($type) || $type === '') {
            throw new RuntimeException('rules_ref.type must be a non-empty string.');
        }
        if (!is_string($path) || $path === '') {
            throw new RuntimeException('rules_ref.path must be a non-empty string.');
        }

        if ($type === 'options_file') {
            return ['options' => $this->readOptionsListFromManifestRef($path)];
        }

        if ($type === 'vehicle_models_by_brand_slug') {
            $data = $this->readRefJson($path, expectedType: 'object');
            if (!is_array($data) || !is_array($data['brand_slug_to_models'] ?? null)) {
                throw new RuntimeException("{$path} must contain brand_slug_to_models object.");
            }
            $map = $data['brand_slug_to_models'];
            $models = $map[$categorySlug] ?? [];
            if (!is_array($models)) {
                $models = [];
            }
            $out = [];
            foreach ($models as $m) {
                if (is_string($m) && $m !== '') {
                    $out[] = $m;
                }
            }
            // IMPORTANT: preserve manifest-provided order.
            // Some sources (e.g., arabam.com) have a meaningful model ordering; sorting here breaks "birebir" exports.
            return ['options' => $out];
        }

        throw new RuntimeException("Unsupported rules_ref.type: {$type}");
    }

    /**
     * @return list<string>
     */
    private function readOptionsListFromManifestRef(string $relativePath): array
    {
        $data = $this->readRefJson($relativePath, expectedType: 'array');
        if (!is_array($data)) {
            throw new RuntimeException("{$relativePath} must be a JSON array.");
        }
        $out = [];
        foreach ($data as $idx => $v) {
            if (!is_string($v) || $v === '') {
                throw new RuntimeException("{$relativePath}[$idx] must be a non-empty string.");
            }
            $out[] = $v;
        }
        return $out;
    }

    private function readRefJson(string $relativePath, string $expectedType = 'any'): mixed
    {
        $rel = str_replace('\\', '/', ltrim($relativePath, "\\/"));
        $path = $this->basePath . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $rel);

        $cacheKey = "ref:{$expectedType}:{$rel}";
        if (array_key_exists($cacheKey, $this->refCache)) {
            return $this->refCache[$cacheKey];
        }

        $data = $this->readJsonFile($path, expectedType: $expectedType);
        $this->refCache[$cacheKey] = $data;
        return $data;
    }

    /**
     * @return list<array{category_slug:string,attribute_key:string}>
     */
    private function expandSchemaRowsForPlan(array $schemaBlocks): array
    {
        $rows = [];
        foreach ($schemaBlocks as $block) {
            $categorySlugs = $block['category_slugs'] ?? [];
            $fields = $block['fields'] ?? [];
            foreach ($categorySlugs as $categorySlug) {
                foreach ($fields as $f) {
                    $rows[] = [
                        'category_slug' => (string)$categorySlug,
                        'attribute_key' => (string)($f['attribute_key'] ?? ''),
                    ];
                }
            }
        }
        return $rows;
    }

    /**
     * @return array<string,bool> keys => true
     */
    private function safeExistingKeys(string $table, string $column): array
    {
        if (!Schema::hasTable($table)) {
            return [];
        }
        /** @var array<int,string> $keys */
        $keys = DB::table($table)->select($column)->pluck($column)->all();
        $set = [];
        foreach ($keys as $k) {
            $set[(string)$k] = true;
        }
        return $set;
    }

    /**
     * @return array<string,bool> "category_slug|attribute_key" => true
     */
    private function safeExistingSchemaPairs(): array
    {
        if (!Schema::hasTable('category_filter_schema') || !Schema::hasTable('categories')) {
            return [];
        }

        // Join to read slugs. This is for dry-run reporting only.
        $rows = DB::table('category_filter_schema')
            ->join('categories', 'categories.id', '=', 'category_filter_schema.category_id')
            ->select(['categories.slug as category_slug', 'category_filter_schema.attribute_key as attribute_key'])
            ->get();

        $set = [];
        foreach ($rows as $r) {
            $set[((string)$r->category_slug) . '|' . ((string)$r->attribute_key)] = true;
        }
        return $set;
    }

    private function assertDbReadyForApply(): void
    {
        foreach (['categories', 'attributes', 'category_filter_schema'] as $table) {
            if (!Schema::hasTable($table)) {
                throw new RuntimeException("DB is not migrated: missing table {$table}. Run migrations first.");
            }
        }

        // Ensure schema columns exist (migrations must have run)
        foreach (['ui_component', 'required', 'filter_mode', 'rules_json', 'applies_to_transaction_modes'] as $col) {
            if (!Schema::hasColumn('category_filter_schema', $col)) {
                throw new RuntimeException("DB schema is missing category_filter_schema.{$col}. Run latest migrations first.");
            }
        }
    }

    private function assertDbIsCleanForV1Apply(): void
    {
        $counts = [
            'categories' => (int)DB::table('categories')->count(),
            'attributes' => (int)DB::table('attributes')->count(),
            'category_filter_schema' => (int)DB::table('category_filter_schema')->count(),
        ];

        $nonEmpty = array_filter($counts, fn ($c) => $c > 0);
        if (count($nonEmpty) > 0) {
            $details = implode(', ', array_map(
                fn ($k, $v) => "{$k}={$v}",
                array_keys($counts),
                array_values($counts)
            ));
            throw new RuntimeException(
                "V1 apply requires a clean DB (migrate:fresh). Non-empty tables detected: {$details}"
            );
        }
    }

    /**
     * @param list<array{slug:string,parent_slug:?string,title:string,status:string,sort_order:int}> $categories
     * @return array<string,int> slug => id
     */
    private function insertCategoriesParentFirst(array $categories, string $now, array $slugToIdInitial = []): array
    {
        // Build index
        $pending = [];
        foreach ($categories as $c) {
            $pending[$c['slug']] = $c;
        }

        $slugToId = $slugToIdInitial;

        // Fast path: nothing to do
        if (count($pending) === 0) {
            return $slugToId;
        }

        while (count($pending) > 0) {
            $batch = [];
            $batchSlugs = [];

            foreach ($pending as $slug => $c) {
                $p = $c['parent_slug'];
                if ($p === null || isset($slugToId[$p])) {
                    $batch[] = [
                        'parent_id' => $p === null ? null : $slugToId[$p],
                        'slug' => $c['slug'],
                        'name' => $c['title'],
                        'vertical' => null,
                        'status' => $c['status'],
                        'sort_order' => $c['sort_order'],
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                    $batchSlugs[] = $slug;
                }
            }

            if (count($batch) === 0) {
                $stuck = implode(', ', array_keys($pending));
                throw new RuntimeException("Unable to resolve category parents (cycle?) stuck slugs: {$stuck}");
            }

            $this->insertChunked('categories', $batch);

            $ids = DB::table('categories')->whereIn('slug', $batchSlugs)->pluck('id', 'slug');
            foreach ($ids as $slug => $id) {
                $slugToId[(string)$slug] = (int)$id;
                unset($pending[(string)$slug]);
            }
        }

        return $slugToId;
    }

    /**
     * Insert rows in chunks to avoid driver parameter limits (e.g. PostgreSQL max bind params = 65535).
     *
     * @param list<array<string,mixed>> $rows
     */
    private function insertChunked(string $table, array $rows, int $maxParams = 60000): void
    {
        if (count($rows) === 0) {
            return;
        }

        $cols = count($rows[0]);
        if ($cols <= 0) {
            return;
        }

        $rowsPerChunk = (int) floor($maxParams / $cols);
        if ($rowsPerChunk < 1) {
            $rowsPerChunk = 1;
        }

        foreach (array_chunk($rows, $rowsPerChunk) as $chunk) {
            DB::table($table)->insert($chunk);
        }
    }

    /**
     * V2: Apply slug renames from aliases.json.
     *
     * Contract:
     * - If old slug exists and new slug does not exist => rename (update slug).
     * - If both exist => FAIL (ambiguous).
     * - If old missing => ignore.
     *
     * @param array<string,string> $aliases
     */
    private function applyCategoryAliasesOrFail(array $aliases): void
    {
        if (count($aliases) === 0) {
            return;
        }
        foreach ($aliases as $old => $new) {
            $old = (string)$old;
            $new = is_string($new) ? $new : (string)$new;
            if ($old === '' || $new === '' || $old === $new) {
                continue;
            }
            $oldRow = DB::table('categories')->where('slug', $old)->first();
            if (!$oldRow) {
                continue;
            }
            $newRow = DB::table('categories')->where('slug', $new)->first();
            if ($newRow) {
                throw new RuntimeException("Alias conflict: both old and new slugs exist in DB: {$old} -> {$new}");
            }
            DB::table('categories')->where('slug', $old)->update(['slug' => $new]);
        }
    }
}


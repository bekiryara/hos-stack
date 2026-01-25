<?php

// Helper function to generate deterministic UUID from string
if (!function_exists('generate_tenant_uuid')) {
    function generate_tenant_uuid($tenantString) {
        // Use MD5 hash to create deterministic UUID-like string
        $hash = md5('tenant-namespace-' . $tenantString);
        return sprintf('%08s-%04s-%04s-%04s-%012s',
            substr($hash, 0, 8),
            substr($hash, 8, 4),
            substr($hash, 12, 4),
            substr($hash, 16, 4),
            substr($hash, 20, 12)
        );
    }
}

// Helper function to get active tenant ID from request (if exists in current api.php, move it here)
// Note: Currently not found in routes, but adding placeholder for future use
if (!function_exists('pazar_active_tenant_id')) {
    function pazar_active_tenant_id() {
        // Get from request header X-Active-Tenant-Id
        $request = request();
        return $request->header('X-Active-Tenant-Id');
    }
}

// Helper function to build category tree (WP-17: extract from closure, WP-72: optimized to O(n))
// WP-72: Changed from O(n²) to O(n) by building index first, but output remains identical
if (!function_exists('pazar_build_tree')) {
    function pazar_build_tree(array $categories, $parentId = null) {
        // WP-72: Build index by parent_id for O(n) lookup instead of O(n²) nested loops
        $indexedByParent = [];
        foreach ($categories as $category) {
            $pid = $category['parent_id'] ?? null;
            if (!isset($indexedByParent[$pid])) {
                $indexedByParent[$pid] = [];
            }
            $indexedByParent[$pid][] = $category;
        }
        
        // Recursive function using index (O(n) total)
        $buildBranch = function($pid) use (&$buildBranch, $indexedByParent) {
            $branch = [];
            if (!isset($indexedByParent[$pid])) {
                return $branch;
            }
            
            foreach ($indexedByParent[$pid] as $category) {
                $children = $buildBranch($category['id']);
                if (!empty($children)) {
                    $category['children'] = $children;
                }
                $branch[] = $category;
            }
            return $branch;
        };
        
        return $buildBranch($parentId);
    }
}

// Helper function to get all descendant category IDs recursively (WP-48, WP-72: optimized with CTE)
// Returns array of category IDs including the root category and all its descendants
if (!function_exists('pazar_category_descendant_ids')) {
    function pazar_category_descendant_ids(int $rootId): array {
        // WP-72: Use PostgreSQL recursive CTE to avoid N+1 queries
        // Single query instead of recursive PHP function calls
        $results = DB::select("
            WITH RECURSIVE category_tree AS (
                -- Base case: start with root category
                SELECT id, parent_id
                FROM categories
                WHERE id = ? AND status = 'active'
                
                UNION ALL
                
                -- Recursive case: get children of current level
                SELECT c.id, c.parent_id
                FROM categories c
                INNER JOIN category_tree ct ON c.parent_id = ct.id
                WHERE c.status = 'active'
            )
            SELECT id FROM category_tree
        ", [$rootId]);
        
        return array_map(function($row) {
            return (int) $row->id;
        }, $results);
    }
}

// Helper function to get SQL snippet and bindings for category descendant CTE (WP-73)
// Returns array with 'sql' (subquery snippet) and 'bindings' (array with root category id)
// Use in whereRaw("category_id IN (<sql>)", bindings)
if (!function_exists('pazar_category_descendant_cte_in_clause_sql')) {
    function pazar_category_descendant_cte_in_clause_sql(int $rootId): array {
        // WP-73: Return CTE subquery as SQL snippet to avoid building large ID arrays in PHP
        // Must include root category id in results
        return [
            'sql' => "(WITH RECURSIVE category_tree AS (
                SELECT id FROM categories WHERE id = ? AND status = 'active'
                UNION ALL
                SELECT c.id FROM categories c
                INNER JOIN category_tree ct ON c.parent_id = ct.id
                WHERE c.status = 'active'
            ) SELECT id FROM category_tree)",
            'bindings' => [$rootId]
        ];
    }
}


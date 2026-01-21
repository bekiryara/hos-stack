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

// Helper function to build category tree (WP-17: extract from closure to avoid redeclare risk)
if (!function_exists('pazar_build_tree')) {
    function pazar_build_tree(array $categories, $parentId = null) {
        $branch = [];
        foreach ($categories as $category) {
            if ($category['parent_id'] == $parentId) {
                $children = pazar_build_tree($categories, $category['id']);
                if (!empty($children)) {
                    $category['children'] = $children;
                }
                $branch[] = $category;
            }
        }
        return $branch;
    }
}


<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Fix Turkish character corruption in `city` filter options.
 *
 * Root cause (common on Windows): reading UTF-8 files with a non-UTF8 default encoding
 * and persisting the corrupted strings (e.g. "İ" -> "??").
 *
 * This migration re-applies the canonical list from `catalog/manifests/cities.tr.json`
 * into `category_filter_schema.rules_json` for `attribute_key = city`.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('category_filter_schema')) {
            return;
        }
        if (!Schema::hasColumn('category_filter_schema', 'rules_json')) {
            return;
        }

        // V2: Manifests root can be external (env CATALOG_MANIFESTS_PATH).
        // Support both legacy layout:
        // - <root>/cities.tr.json
        // and artifact layout:
        // - <root>/options/cities.tr.json
        $root = env('CATALOG_MANIFESTS_PATH', base_path('catalog/manifests'));
        $root = is_string($root) ? trim($root) : base_path('catalog/manifests');
        if (!is_dir($root)) {
            $fallback = base_path('catalog/manifests_ci');
            if (is_dir($fallback)) {
                $root = $fallback;
            }
        }
        $candidates = [
            rtrim($root, "\\/") . DIRECTORY_SEPARATOR . 'cities.tr.json',
            rtrim($root, "\\/") . DIRECTORY_SEPARATOR . 'options' . DIRECTORY_SEPARATOR . 'cities.tr.json',
        ];
        $manifestPath = null;
        foreach ($candidates as $p) {
            if (is_string($p) && is_file($p)) {
                $manifestPath = $p;
                break;
            }
        }
        if (!$manifestPath) return;

        $raw = file_get_contents($manifestPath);
        $options = json_decode($raw ?: '[]', true);

        if (!is_array($options) || count($options) === 0) {
            return;
        }

        $rulesJson = json_encode(['options' => array_values($options)], JSON_UNESCAPED_UNICODE);

        DB::table('category_filter_schema')
            ->where('attribute_key', 'city')
            ->update([
                'ui_component' => 'select',
                'rules_json' => $rulesJson,
            ]);
    }

    public function down(): void
    {
        // No-op: we don't want to restore the corrupted prior state.
    }
};


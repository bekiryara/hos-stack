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

        $manifestPath = base_path('catalog/manifests/cities.tr.json');
        if (!is_file($manifestPath)) {
            return;
        }

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


<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('attributes') || !Schema::hasTable('categories') || !Schema::hasTable('category_filter_schema')) {
            return;
        }

        $attributeDefs = [
            'availability_days' => [
                'value_type' => 'enum',
                'unit' => null,
                'description' => 'Musait gunler',
            ],
            'availability_time_window' => [
                'value_type' => 'enum',
                'unit' => null,
                'description' => 'Musait saat araligi',
            ],
        ];

        foreach ($attributeDefs as $key => $def) {
            DB::table('attributes')->updateOrInsert(
                ['key' => $key],
                [
                    'value_type' => $def['value_type'],
                    'unit' => $def['unit'],
                    'description' => $def['description'],
                    'updated_at' => now(),
                    'created_at' => now(),
                ]
            );
        }

        $pilotCategories = [
            'bando' => ['reservation'],
            'wedding-hall' => ['reservation'],
            'otomobil-alfa-romeo' => ['rental'],
            'daire' => ['reservation', 'rental'],
        ];

        $daysOptions = [
            'Pazartesi',
            'Sali',
            'Carsamba',
            'Persembe',
            'Cuma',
            'Cumartesi',
            'Pazar',
        ];

        $timeWindowOptions = [
            '08:00-12:00',
            '12:00-18:00',
            '18:00-23:00',
        ];

        $fieldDefs = [
            'availability_days' => [
                'ui_component' => 'select',
                'required' => false,
                'filter_mode' => 'availability',
                'rules_json' => json_encode(['options' => $daysOptions], JSON_UNESCAPED_UNICODE),
                'sort_order' => 910,
            ],
            'availability_time_window' => [
                'ui_component' => 'select',
                'required' => false,
                'filter_mode' => 'availability',
                'rules_json' => json_encode(['options' => $timeWindowOptions], JSON_UNESCAPED_UNICODE),
                'sort_order' => 911,
            ],
        ];

        foreach ($pilotCategories as $slug => $modes) {
            $categoryId = DB::table('categories')->where('slug', $slug)->value('id');
            if (!$categoryId) {
                continue;
            }

            foreach ($fieldDefs as $attributeKey => $fieldDef) {
                DB::table('category_filter_schema')->updateOrInsert(
                    [
                        'category_id' => $categoryId,
                        'attribute_key' => $attributeKey,
                    ],
                    [
                        'status' => 'active',
                        'sort_order' => $fieldDef['sort_order'],
                        'ui_component' => $fieldDef['ui_component'],
                        'required' => $fieldDef['required'],
                        'filter_mode' => $fieldDef['filter_mode'],
                        'rules_json' => $fieldDef['rules_json'],
                        'applies_to_transaction_modes' => json_encode(array_values($modes), JSON_UNESCAPED_UNICODE),
                        'updated_at' => now(),
                        'created_at' => now(),
                    ]
                );
            }
        }
    }

    public function down(): void
    {
        if (!Schema::hasTable('categories') || !Schema::hasTable('category_filter_schema')) {
            return;
        }

        $slugs = ['bando', 'wedding-hall', 'otomobil-alfa-romeo', 'daire'];
        $categoryIds = DB::table('categories')->whereIn('slug', $slugs)->pluck('id')->all();
        if (empty($categoryIds)) {
            return;
        }

        DB::table('category_filter_schema')
            ->whereIn('category_id', $categoryIds)
            ->whereIn('attribute_key', ['availability_days', 'availability_time_window'])
            ->update([
                'status' => 'inactive',
                'updated_at' => now(),
            ]);
    }
};


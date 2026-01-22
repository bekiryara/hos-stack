<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

// Catalog Spine Endpoints (SPEC §6.2, WP-2)
// GET /v1/categories (tree format)
// WP-8: GUEST+ persona (no headers required)
Route::middleware([\App\Http\Middleware\PersonaScope::class . ':guest'])->get('/v1/categories', function () {
    
    // Fetch all categories with parent relationships
    $categories = DB::table('categories')
        ->where('status', 'active')
        ->orderBy('sort_order')
        ->get()
        ->map(function ($cat) {
            return [
                'id' => $cat->id,
                'parent_id' => $cat->parent_id,
                'slug' => $cat->slug,
                'name' => $cat->name,
                'vertical' => $cat->vertical,
                'status' => $cat->status,
            ];
        })
        ->toArray();
    
    // Build tree structure (WP-17 v2: use helper function to avoid redeclare risk)
    $tree = pazar_build_tree($categories);
    
    return response()->json($tree);
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
    
    // Fetch filter schema for this category
    // Check if new fields exist (after migration)
    $hasNewFields = Schema::hasColumn('category_filter_schema', 'ui_component');
    
    $selectFields = [
        'category_filter_schema.id',
        'category_filter_schema.attribute_key',
        'category_filter_schema.status',
        'category_filter_schema.sort_order',
        'attributes.value_type',
        'attributes.unit',
        'attributes.description'
    ];
    
    if ($hasNewFields) {
        $selectFields = array_merge($selectFields, [
            'category_filter_schema.ui_component',
            'category_filter_schema.required',
            'category_filter_schema.filter_mode',
            'category_filter_schema.rules_json'
        ]);
    }
    
    $schema = DB::table('category_filter_schema')
        ->join('attributes', 'category_filter_schema.attribute_key', '=', 'attributes.key')
        ->where('category_filter_schema.category_id', $id)
        ->where('category_filter_schema.status', 'active')
        ->orderBy('category_filter_schema.sort_order')
        ->select($selectFields)
        ->get()
        ->map(function ($item) use ($hasNewFields) {
            $result = [
                'attribute_key' => $item->attribute_key,
                'value_type' => $item->value_type,
                'unit' => $item->unit,
                'description' => $item->description,
                'status' => $item->status,
                'sort_order' => $item->sort_order,
            ];
            
            // Add new fields if migration has run
            if ($hasNewFields) {
                $result['ui_component'] = $item->ui_component;
                $result['required'] = (bool) $item->required;
                $result['filter_mode'] = $item->filter_mode;
                
                // Parse rules_json if present
                if ($item->rules_json) {
                    $rules = json_decode($item->rules_json, true);
                    if ($rules) {
                        $result['rules'] = $rules;
                    }
                }
            }
            
            return $result;
        })
        ->toArray();
    
    return response()->json([
        'category_id' => (int) $id,
        'category_slug' => $category->slug,
        'filters' => $schema
    ]);
});


<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Listing API Spine Seeder
 * 
 * Inserts sample listings for marketplace world if table is empty.
 * Dev-only safe: checks if data exists before inserting.
 */
final class ListingApiSpineSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        // Check if listings table already has data
        $existingCount = DB::table('listings')->count();
        if ($existingCount > 0) {
            $this->command->info('Listings table already has data, skipping seed.');
            return;
        }

        $enabledWorlds = ['marketplace'];
        $sampleData = [
            'marketplace' => [
                ['Sample Listing A', 15000.00, 'TRY'],
                ['Sample Listing B', 250.00, 'TRY'],
                ['Sample Listing C', 150.00, 'TRY'],
            ],
        ];

        $now = now();

        foreach ($enabledWorlds as $world) {
            foreach ($sampleData[$world] as $item) {
                [$title, $price, $currency] = $item;

                DB::table('listings')->insert([
                    'id' => (string) Str::uuid(),
                    'tenant_id' => (string) Str::uuid(), // Required by migration
                    'world' => $world,
                    'title' => $title,
                    'status' => 'published', // Use 'published' to match existing migration
                    'price_amount' => $price, // Use price_amount to match existing migration
                    'currency' => $currency,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }
        }

        $this->command->info('Inserted 3 sample listings for marketplace world.');
    }
}


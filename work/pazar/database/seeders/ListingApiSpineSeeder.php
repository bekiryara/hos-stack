<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Listing API Spine Seeder
 * 
 * Lightweight seed for Product API Spine READ MVP.
 * Inserts 3 sample rows per enabled world (commerce, food, rentals) if table is empty.
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

        $enabledWorlds = ['commerce', 'food', 'rentals'];
        $sampleData = [
            'commerce' => [
                ['Laptop Computer', 15000.00, 'TRY'],
                ['Wireless Mouse', 250.00, 'TRY'],
                ['USB-C Cable', 150.00, 'TRY'],
            ],
            'food' => [
                ['Pizza Margherita', 120.00, 'TRY'],
                ['Caesar Salad', 85.00, 'TRY'],
                ['Chocolate Cake', 60.00, 'TRY'],
            ],
            'rentals' => [
                ['Studio Apartment', 5000.00, 'TRY'],
                ['Office Space', 8000.00, 'TRY'],
                ['Conference Room', 500.00, 'TRY'],
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

        $this->command->info('Inserted 3 sample listings for each enabled world (commerce, food, rentals).');
    }
}


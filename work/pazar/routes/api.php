<?php

use App\Http\Controllers\Api\Commerce\ListingController as CommerceListingController;
use App\Http\Controllers\Api\Food\FoodListingController;
use App\Http\Controllers\Api\Rentals\RentalsListingController;
use App\Http\Controllers\Api\ProductController;
use App\Http\Controllers\ListingController;
use App\Http\Controllers\MetricsController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
|
| API routes for Pazar application.
|
*/

// Product API Spine v1 (enabled worlds: commerce, food, rentals)
// Contract-first, stub-only: all endpoints return 501 NOT_IMPLEMENTED
// GET: public, POST/PATCH/DELETE: auth.any required

// Canonical Product Core Spine (read/create/disable, world-agnostic)
Route::prefix('v1')->middleware(['auth.any', 'resolve.tenant', 'tenant.user'])->group(function () {
    Route::get('/products', [ProductController::class, 'index'])->name('api.v1.products.index');
    Route::get('/products/{id}', [ProductController::class, 'show'])->name('api.v1.products.show');
    Route::post('/products', [ProductController::class, 'store'])->name('api.v1.products.store');
    Route::patch('/products/{id}/disable', [ProductController::class, 'disable'])->name('api.v1.products.disable');
});

// Commerce listings spine
Route::prefix('v1/commerce')->defaults('world', 'commerce')->group(function () {
    // GET routes (world.lock:commerce + auth.any + resolve.tenant + tenant.user required)
    Route::middleware(['world.lock:commerce', 'auth.any', 'resolve.tenant', 'tenant.user'])->group(function () {
        Route::get('/listings', [CommerceListingController::class, 'index'])->name('api.v1.commerce.listings.index');
        Route::get('/listings/{id}', [CommerceListingController::class, 'show'])->name('api.v1.commerce.listings.show');
    });
    
    // Write routes (world.lock:commerce + auth.any + resolve.tenant + tenant.user required)
    Route::middleware(['world.lock:commerce', 'auth.any', 'resolve.tenant', 'tenant.user'])->group(function () {
        Route::post('/listings', [CommerceListingController::class, 'store'])->name('api.v1.commerce.listings.store');
        Route::patch('/listings/{id}', [CommerceListingController::class, 'update'])->name('api.v1.commerce.listings.update');
        Route::delete('/listings/{id}', [CommerceListingController::class, 'destroy'])->name('api.v1.commerce.listings.destroy');
    });
});

// Food listings spine
Route::prefix('v1/food')->defaults('world', 'food')->group(function () {
    // GET routes (auth.any + resolve.tenant + tenant.user required)
    Route::middleware(['auth.any', 'resolve.tenant', 'tenant.user'])->group(function () {
        Route::get('/listings', [FoodListingController::class, 'index'])->name('api.v1.food.listings.index');
        Route::get('/listings/{id}', [FoodListingController::class, 'show'])->name('api.v1.food.listings.show');
    });
    
    // Write routes (auth.any + resolve.tenant + tenant.user required)
    Route::middleware(['auth.any', 'resolve.tenant', 'tenant.user'])->group(function () {
        Route::post('/listings', [FoodListingController::class, 'store'])->name('api.v1.food.listings.store');
        Route::patch('/listings/{id}', [FoodListingController::class, 'update'])->name('api.v1.food.listings.update');
        Route::delete('/listings/{id}', [FoodListingController::class, 'destroy'])->name('api.v1.food.listings.destroy');
    });
});

// Rentals listings spine
Route::prefix('v1/rentals')->defaults('world', 'rentals')->group(function () {
    // GET routes (auth.any + resolve.tenant + tenant.user required)
    Route::middleware(['auth.any', 'resolve.tenant', 'tenant.user'])->group(function () {
        Route::get('/listings', [RentalsListingController::class, 'index'])->name('api.v1.rentals.listings.index');
        Route::get('/listings/{id}', [RentalsListingController::class, 'show'])->name('api.v1.rentals.listings.show');
    });
    
    // Write routes (auth.any + resolve.tenant + tenant.user required)
    Route::middleware(['auth.any', 'resolve.tenant', 'tenant.user'])->group(function () {
        Route::post('/listings', [RentalsListingController::class, 'store'])->name('api.v1.rentals.listings.store');
        Route::patch('/listings/{id}', [RentalsListingController::class, 'update'])->name('api.v1.rentals.listings.update');
        Route::delete('/listings/{id}', [RentalsListingController::class, 'destroy'])->name('api.v1.rentals.listings.destroy');
    });
});

// Metrics endpoint (public, no auth)
Route::get('/metrics', [MetricsController::class, 'index'])->name('api.metrics');

// Public routes (no auth)
Route::prefix('{world}')->middleware(['world.resolve'])->group(function () {
    Route::get('/listings/search', [ListingController::class, 'search'])->name('api.listings.search');
    Route::get('/listings/{id}', [ListingController::class, 'show'])->name('api.listings.show');
});

// Panel routes (auth required: auth.any + tenant.user + tenant.resolve)
Route::prefix('{world}/panel')->middleware(['world.resolve', 'auth.any', 'resolve.tenant', 'tenant.user'])->group(function () {
    Route::get('/listings', [ListingController::class, 'index'])->name('api.panel.listings.index');
    Route::post('/listings', [ListingController::class, 'store'])->name('api.panel.listings.store');
    Route::patch('/listings/{id}', [ListingController::class, 'update'])->name('api.panel.listings.update');
    Route::post('/listings/{id}/publish', [ListingController::class, 'publish'])->name('api.panel.listings.publish');
    Route::post('/listings/{id}/unpublish', [ListingController::class, 'unpublish'])->name('api.panel.listings.unpublish');
});


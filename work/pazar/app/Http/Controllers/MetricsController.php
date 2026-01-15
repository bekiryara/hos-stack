<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

/**
 * Metrics Controller
 * 
 * Provides Prometheus-compatible metrics for observability.
 * Simple in-memory counters for product operations.
 */
final class MetricsController extends Controller
{
    /**
     * Simple in-memory counters (for MVP, will be replaced with proper metrics library later)
     */
    private static $counters = [
        'pazar_product_create_total' => 0,
        'pazar_product_disable_total' => 0,
    ];

    /**
     * Get metrics (Prometheus-compatible format)
     * 
     * GET /metrics
     * 
     * Token support: If METRICS_TOKEN env var is set, requires token via:
     * - Header: X-Metrics-Token
     * - Query: ?token=
     * - Authorization: Bearer <token>
     */
    public function index(Request $request): Response
    {
        // Token validation (if METRICS_TOKEN is set)
        $requiredToken = env('METRICS_TOKEN');
        if ($requiredToken) {
            $providedToken = $request->header('X-Metrics-Token') 
                ?? $request->query('token')
                ?? ($request->bearerToken() ?: null);
            
            if (!$providedToken || $providedToken !== $requiredToken) {
                return response("unauthorized\n", 401)
                    ->header('Content-Type', 'text/plain; charset=utf-8');
            }
        }
        
        $output = [];
        
        // Baseline metrics (required by alert rules)
        $version = env('APP_VERSION', 'unknown');
        $output[] = "# HELP pazar_build_info Build information";
        $output[] = "# TYPE pazar_build_info gauge";
        $output[] = "pazar_build_info{service=\"pazar\",version=\"$version\"} 1";
        
        $output[] = "# HELP pazar_time_seconds Current Unix timestamp";
        $output[] = "# TYPE pazar_time_seconds gauge";
        $output[] = 'pazar_time_seconds ' . microtime(true);
        
        $output[] = "# HELP pazar_php_memory_usage_bytes Current PHP memory usage in bytes";
        $output[] = "# TYPE pazar_php_memory_usage_bytes gauge";
        $output[] = 'pazar_php_memory_usage_bytes ' . memory_get_usage(false);
        
        $output[] = "# HELP pazar_php_memory_peak_bytes Peak PHP memory usage in bytes";
        $output[] = "# TYPE pazar_php_memory_peak_bytes gauge";
        $output[] = 'pazar_php_memory_peak_bytes ' . memory_get_peak_usage(false);
        
        // Product create counter
        $output[] = '# HELP pazar_product_create_total Total number of products created';
        $output[] = '# TYPE pazar_product_create_total counter';
        $output[] = 'pazar_product_create_total ' . self::$counters['pazar_product_create_total'];
        
        // Product disable counter
        $output[] = '# HELP pazar_product_disable_total Total number of products disabled';
        $output[] = '# TYPE pazar_product_disable_total counter';
        $output[] = 'pazar_product_disable_total ' . self::$counters['pazar_product_disable_total'];
        
        // Products total (from DB, cheap query)
        try {
            $productsTotal = Product::count();
            $output[] = '# HELP pazar_products_total Total number of products in database';
            $output[] = '# TYPE pazar_products_total gauge';
            $output[] = "pazar_products_total $productsTotal";
        } catch (\Exception $e) {
            // If DB query fails, skip this metric
        }
        
        return response(implode("\n", $output) . "\n", 200)
            ->header('Content-Type', 'text/plain; version=0.0.4; charset=utf-8')
            ->header('Cache-Control', 'no-store');
    }

    /**
     * Increment product create counter (called from ProductController)
     */
    public static function incrementProductCreate(): void
    {
        self::$counters['pazar_product_create_total']++;
    }

    /**
     * Increment product disable counter (called from ProductController)
     */
    public static function incrementProductDisable(): void
    {
        self::$counters['pazar_product_disable_total']++;
    }
}






<?php

use Illuminate\Support\Facades\Route;

// Load helpers first (WP-17 v2)
require_once __DIR__.'/_helpers.php';

// Load route modules in deterministic order (WP-17 v2: numbered files for explicit ordering)
// Order: metrics -> ping -> world_status -> catalog -> listings -> reservations -> orders -> rentals
require_once __DIR__.'/api/00_metrics.php';
require_once __DIR__.'/api/00_ping.php';
require_once __DIR__.'/api/01_world_status.php';
require_once __DIR__.'/api/02_catalog.php';
require_once __DIR__.'/api/03a_listings_write.php';
require_once __DIR__.'/api/03c_offers.php';
require_once __DIR__.'/api/03b_listings_read.php';
require_once __DIR__.'/api/04_reservations.php';
require_once __DIR__.'/api/05_orders.php';
require_once __DIR__.'/api/06_rentals.php';
require_once __DIR__.'/api/messaging.php';
require_once __DIR__.'/api/account_portal.php';

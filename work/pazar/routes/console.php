<?php

use App\Catalog\Import\CatalogImportService;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

// Artisan closure commands and schedule (pazar: no custom commands yet)
// Schedule::command('inspire')->hourly();

Artisan::command('catalog:import {--dry-run : Report planned DB changes} {--apply : Apply manifests to DB (clean DB only)}', function () {
    /** @var \Illuminate\Console\Command $this */

    $dryRun = (bool) $this->option('dry-run');
    $apply = (bool) $this->option('apply');

    if ($dryRun && $apply) {
        $this->error('Use either --dry-run or --apply (not both).');
        return 1;
    }

    // Default mode: dry-run (safe)
    if (!$dryRun && !$apply) {
        $dryRun = true;
    }

    $svc = CatalogImportService::fromDefaultPath();

    try {
        $m = $svc->loadManifests();
        $svc->validateOrFail($m);

        $plan = $svc->plan($m);

        $this->line('catalog:import (clean install)');
        $this->line('generated_at: ' . ($plan['generated_at'] ?? '-'));
        $this->newLine();

        $this->info('Planned changes');
        $this->line(sprintf(
            'categories: insert=%d update=%d total=%d',
            $plan['categories']['insert'],
            $plan['categories']['update'],
            $plan['categories']['total'],
        ));
        $this->line(sprintf(
            'attributes: insert=%d update=%d total=%d',
            $plan['attributes']['insert'],
            $plan['attributes']['update'],
            $plan['attributes']['total'],
        ));
        $this->line(sprintf(
            'schema: insert=%d update=%d total=%d',
            $plan['schema']['insert'],
            $plan['schema']['update'],
            $plan['schema']['total'],
        ));
        $this->newLine();

        $this->info('Samples (first 20)');
        $this->line('categories: ' . json_encode($plan['samples']['categories'], JSON_UNESCAPED_UNICODE));
        $this->line('attributes: ' . json_encode($plan['samples']['attributes'], JSON_UNESCAPED_UNICODE));
        $this->line('schema: ' . json_encode($plan['samples']['schema'], JSON_UNESCAPED_UNICODE));
        $this->newLine();

        if ($dryRun) {
            $this->comment('Dry-run mode: no DB changes were applied.');
            return 0;
        }

        // Apply mode (clean install rule: clean DB only; transactional).
        $svc->apply($m);
        $this->info('Apply OK (transaction committed).');
        return 0;
    } catch (Throwable $e) {
        $this->error($e->getMessage());
        return 1;
    }
})->purpose('Import catalog manifests into DB (clean install: clean DB only, fail-fast).');

Artisan::command('catalog:sync {--dry-run : Report planned DB changes (in-place sync)} {--apply : Sync manifests to DB (V2: in-place, transactional)}', function () {
    /** @var \Illuminate\Console\Command $this */

    $dryRun = (bool) $this->option('dry-run');
    $apply = (bool) $this->option('apply');

    if ($dryRun && $apply) {
        $this->error('Use either --dry-run or --apply (not both).');
        return 1;
    }

    // Default mode: dry-run (safe)
    if (!$dryRun && !$apply) {
        $dryRun = true;
    }

    $svc = CatalogImportService::fromDefaultPath();

    try {
        $m = $svc->loadManifests();
        $svc->validateOrFail($m);

        $plan = $svc->plan($m);

        $this->line('catalog:sync (in-place)');
        $this->line('generated_at: ' . ($plan['generated_at'] ?? '-'));
        $this->newLine();

        $this->info('Planned changes (in-place sync)');
        $this->line(sprintf(
            'categories: insert=%d update=%d total=%d',
            $plan['categories']['insert'],
            $plan['categories']['update'],
            $plan['categories']['total'],
        ));
        $this->line(sprintf(
            'attributes: insert=%d update=%d total=%d',
            $plan['attributes']['insert'],
            $plan['attributes']['update'],
            $plan['attributes']['total'],
        ));
        $this->line(sprintf(
            'schema: insert=%d update=%d total=%d',
            $plan['schema']['insert'],
            $plan['schema']['update'],
            $plan['schema']['total'],
        ));
        $this->newLine();

        $this->info('Samples (first 20)');
        $this->line('categories: ' . json_encode($plan['samples']['categories'], JSON_UNESCAPED_UNICODE));
        $this->line('attributes: ' . json_encode($plan['samples']['attributes'], JSON_UNESCAPED_UNICODE));
        $this->line('schema: ' . json_encode($plan['samples']['schema'], JSON_UNESCAPED_UNICODE));
        $this->newLine();

        if ($dryRun) {
            $this->comment('Dry-run mode: no DB changes were applied.');
            return 0;
        }

        $svc->syncApply($m);
        $this->info('Sync apply OK (transaction committed).');
        return 0;
    } catch (Throwable $e) {
        $this->error($e->getMessage());
        return 1;
    }
})->purpose('Sync catalog manifests into DB (v2: in-place, transactional, no deletes).');

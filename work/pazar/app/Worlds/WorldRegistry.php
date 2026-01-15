<?php

namespace App\Worlds;

use Illuminate\Support\Facades\Config;

/**
 * World Registry Service
 * 
 * Provides access to world configuration (enabled/disabled worlds).
 * Uses config/worlds.php as source of truth.
 */
final class WorldRegistry
{
    /**
     * Get enabled world IDs
     * 
     * @return array<string>
     */
    public function getEnabledWorlds(): array
    {
        return (array) Config::get('worlds.enabled', []);
    }

    /**
     * Get disabled world IDs
     * 
     * @return array<string>
     */
    public function getDisabledWorlds(): array
    {
        return (array) Config::get('worlds.disabled', []);
    }

    /**
     * Check if world is enabled
     * 
     * @param string $worldId
     * @return bool
     */
    public function isEnabled(string $worldId): bool
    {
        return in_array($worldId, $this->getEnabledWorlds(), true);
    }

    /**
     * Check if world is disabled
     * 
     * @param string $worldId
     * @return bool
     */
    public function isDisabled(string $worldId): bool
    {
        return in_array($worldId, $this->getDisabledWorlds(), true);
    }

    /**
     * Check if world exists (enabled or disabled)
     * 
     * @param string $worldId
     * @return bool
     */
    public function exists(string $worldId): bool
    {
        return $this->isEnabled($worldId) || $this->isDisabled($worldId);
    }

    /**
     * Get all world IDs (enabled + disabled)
     * 
     * @return array<string>
     */
    public function getAllWorlds(): array
    {
        return array_merge($this->getEnabledWorlds(), $this->getDisabledWorlds());
    }

    /**
     * Get all worlds with metadata (for UI display)
     * 
     * @return array<string, array{label: string, enabled: bool}>
     */
    public function all(): array
    {
        $labels = [
            'commerce' => 'Pazar (Satış/Alışveriş)',
            'food' => 'Yemek',
            'rentals' => 'Kiralama (Rezervasyon)',
            'services' => 'Hizmetler',
            'real_estate' => 'Emlak',
            'vehicle' => 'Taşıtlar',
        ];

        $result = [];
        foreach ($this->getAllWorlds() as $worldId) {
            $result[$worldId] = [
                'label' => $labels[$worldId] ?? $worldId,
                'enabled' => $this->isEnabled($worldId),
            ];
        }

        return $result;
    }

    /**
     * Get default world key (first enabled world)
     * 
     * @return string
     */
    public function defaultKey(): string
    {
        $enabled = $this->getEnabledWorlds();
        return !empty($enabled) ? (string) reset($enabled) : 'commerce';
    }
}



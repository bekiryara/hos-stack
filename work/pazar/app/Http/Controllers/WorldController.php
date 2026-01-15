<?php

namespace App\Http\Controllers;

use App\Worlds\WorldRegistry;
use Illuminate\Http\Request;

/**
 * World Controller
 * 
 * Handles public routes for enabled worlds (commerce, food, rentals).
 * Disabled worlds are handled by WorldResolver middleware (410 WORLD_CLOSED).
 */
final class WorldController extends Controller
{
    private const WORLD_LABELS = [
        'commerce' => 'Pazar (Satış/Alışveriş)',
        'food' => 'Yemek',
        'rentals' => 'Kiralama (Rezervasyon)',
    ];

    public function __construct(
        private readonly WorldRegistry $worlds
    ) {
    }

    /**
     * World home page
     * 
     * @param Request $request
     * @param string $world
     * @return \Illuminate\View\View|\Illuminate\Http\JsonResponse
     */
    public function home(Request $request, string $world)
    {
        // World context is already validated by WorldResolver middleware
        $worldId = $request->attributes->get('ctx.world', $world);
        $enabledWorlds = $this->worlds->getEnabledWorlds();

        $data = [
            'world' => $worldId,
            'world_label' => self::WORLD_LABELS[$worldId] ?? $worldId,
            'enabled_worlds' => $enabledWorlds,
        ];

        if ($request->expectsJson() || $request->is('*/api/*')) {
            return response()->json([
                'ok' => true,
                'world' => $worldId,
                'label' => $data['world_label'],
                'message' => 'MVP: coming next',
            ]);
        }

        return view('worlds.home', $data);
    }

    /**
     * World search placeholder
     * 
     * @param Request $request
     * @param string $world
     * @return \Illuminate\View\View|\Illuminate\Http\JsonResponse
     */
    public function search(Request $request, string $world)
    {
        // World context is already validated by WorldResolver middleware
        $worldId = $request->attributes->get('ctx.world', $world);

        if ($request->expectsJson() || $request->is('*/api/*')) {
            return response()->json([
                'ok' => true,
                'world' => $worldId,
                'message' => 'Search not implemented yet',
            ]);
        }

        return response()->json([
            'ok' => true,
            'world' => $worldId,
            'message' => 'Search not implemented yet',
        ], 200);
    }
}






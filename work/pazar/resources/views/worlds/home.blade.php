<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{ $world_label }} - Pazar</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            margin: 0;
            padding: 20px;
            background: #f5f5f5;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            margin-top: 0;
        }
        .world-nav {
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #e0e0e0;
        }
        .world-nav a {
            display: inline-block;
            margin-right: 15px;
            color: #0066cc;
            text-decoration: none;
        }
        .world-nav a:hover {
            text-decoration: underline;
        }
        .mvp-notice {
            margin-top: 30px;
            padding: 15px;
            background: #f0f8ff;
            border-left: 4px solid #0066cc;
            border-radius: 4px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>{{ $world_label }}</h1>
        
        <div class="mvp-notice">
            <strong>MVP: coming next</strong>
            <p>This world is under development. Content will be available soon.</p>
        </div>

        <div class="world-nav">
            <strong>Other Worlds:</strong>
            @foreach($enabled_worlds as $enabledWorld)
                @if($enabledWorld !== $world)
                    <a href="{{ route('worlds.home', ['world' => $enabledWorld]) }}">{{ $enabledWorld }}</a>
                @endif
            @endforeach
        </div>
    </div>
</body>
</html>






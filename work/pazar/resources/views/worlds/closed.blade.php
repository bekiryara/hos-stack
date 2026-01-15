<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>World Closed - Pazar</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            margin: 0;
            padding: 20px;
            background: #f5f5f5;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            text-align: center;
        }
        h1 {
            color: #d32f2f;
            margin-top: 0;
        }
        .error-message {
            margin-top: 20px;
            padding: 15px;
            background: #ffebee;
            border-left: 4px solid #d32f2f;
            border-radius: 4px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>World Closed</h1>
        <div class="error-message">
            <p><strong>World "{{ $world }}" is currently closed.</strong></p>
            <p>This world is planned but not yet available.</p>
        </div>
    </div>
</body>
</html>






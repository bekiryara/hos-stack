# Error Contract Runbook

## Standard Error Response Format

All API error responses follow this standard envelope:

```json
{
  "ok": false,
  "error_code": "ERROR_CODE",
  "message": "Human-readable error message",
  "request_id": "uuid-here",
  "details": { /* optional additional details */ }
}
```

## Top 10 Error Codes

### 1. VALIDATION_ERROR
- **HTTP Status:** 422
- **When:** Request validation fails (missing required fields, invalid format, etc.)
- **Details:** Contains `fields` object with validation errors per field
- **Example:**
```json
{
  "ok": false,
  "error_code": "VALIDATION_ERROR",
  "message": "Validation failed.",
  "request_id": "123e4567-e89b-12d3-a456-426614174000",
  "details": {
    "fields": {
      "email": ["The email field is required."],
      "password": ["The password must be at least 8 characters."]
    }
  }
}
```

### 2. NOT_FOUND
- **HTTP Status:** 404
- **When:** Requested resource does not exist
- **Example:**
```json
{
  "ok": false,
  "error_code": "NOT_FOUND",
  "message": "Not found.",
  "request_id": "123e4567-e89b-12d3-a456-426614174000"
}
```

### 3. UNAUTHORIZED
- **HTTP Status:** 401
- **When:** Authentication required but not provided or invalid
- **Example:**
```json
{
  "ok": false,
  "error_code": "UNAUTHORIZED",
  "message": "Unauthenticated.",
  "request_id": "123e4567-e89b-12d3-a456-426614174000"
}
```

### 4. FORBIDDEN
- **HTTP Status:** 403
- **When:** Authenticated but not authorized for the requested action
- **Example:**
```json
{
  "ok": false,
  "error_code": "FORBIDDEN",
  "message": "Forbidden.",
  "request_id": "123e4567-e89b-12d3-a456-426614174000"
}
```

### 5. INTERNAL_ERROR
- **HTTP Status:** 500
- **When:** Unhandled server error
- **Note:** Only generic message exposed in production; exception details logged
- **Example:**
```json
{
  "ok": false,
  "error_code": "INTERNAL_ERROR",
  "message": "Server error.",
  "request_id": "123e4567-e89b-12d3-a456-426614174000"
}
```

### 6. HTTP_ERROR
- **HTTP Status:** 4xx/5xx (varies)
- **When:** HTTP exception with non-standard status code
- **Example:**
```json
{
  "ok": false,
  "error_code": "HTTP_ERROR",
  "message": "Request failed.",
  "request_id": "123e4567-e89b-12d3-a456-426614174000"
}
```

### 7. SERVICE_UNAVAILABLE
- **HTTP Status:** 503
- **When:** External service (e.g., H-OS) unavailable
- **Example:**
```json
{
  "ok": false,
  "error_code": "SERVICE_UNAVAILABLE",
  "message": "Service temporarily unavailable.",
  "request_id": "123e4567-e89b-12d3-a456-426614174000"
}
```

### 8. RATE_LIMIT_EXCEEDED
- **HTTP Status:** 429
- **When:** Rate limit exceeded
- **Example:**
```json
{
  "ok": false,
  "error_code": "RATE_LIMIT_EXCEEDED",
  "message": "Too many requests.",
  "request_id": "123e4567-e89b-12d3-a456-426614174000"
}
```

### 9. CONFLICT
- **HTTP Status:** 409
- **When:** Resource conflict (e.g., duplicate creation)
- **Example:**
```json
{
  "ok": false,
  "error_code": "CONFLICT",
  "message": "Resource already exists.",
  "request_id": "123e4567-e89b-12d3-a456-426614174000"
}
```

### 10. BAD_REQUEST
- **HTTP Status:** 400
- **When:** Malformed request
- **Example:**
```json
{
  "ok": false,
  "error_code": "BAD_REQUEST",
  "message": "Bad request.",
  "request_id": "123e4567-e89b-12d3-a456-426614174000"
}
```

## Finding Errors by Request ID

All error responses include `request_id` field. Use this to find related logs:

1. **Extract request_id from error response:**
```json
{
  "ok": false,
  "error_code": "INTERNAL_ERROR",
  "request_id": "123e4567-e89b-12d3-a456-426614174000"
}
```

2. **Find error log:**
```bash
docker compose exec pazar-app grep "123e4567-e89b-12d3-a456-426614174000" storage/logs/laravel.log
```

3. **Structured error log format:**
```json
{
  "message": "error",
  "context": {
    "event": "error",
    "error_code": "INTERNAL_ERROR",
    "request_id": "123e4567-e89b-12d3-a456-426614174000",
    "route": "api.products.store",
    "method": "POST",
    "world": "commerce",
    "user_id": 42,
    "exception_class": "App\\Exceptions\\ProductException",
    "message": "Failed to create product"
  }
}
```

4. **Full trace using observability runbook:**
   See [`docs/runbooks/observability.md`](observability.md) for detailed request_id-based log/trace finding (10 steps).

## Testing Error Responses

### Test 404 (NOT_FOUND)
```bash
curl -i http://localhost:8080/api/non-existent-endpoint
# Expected: { "ok": false, "error_code": "NOT_FOUND", "request_id": "..." }
```

### Test 422 (VALIDATION_ERROR)
```bash
curl -i -X POST http://localhost:8080/api/products \
  -H "Content-Type: application/json" \
  -d '{}'
# Expected: { "ok": false, "error_code": "VALIDATION_ERROR", "request_id": "...", "details": { "fields": {...} } }
```

## Notes

- **Request ID:** Always present in error responses for correlation
- **Structured Logging:** All errors logged with structured context (event, error_code, request_id, route, method, world, user_id, exception_class)
- **HTTP Status:** Preserved from original exception (404, 422, 500, etc.)
- **Error Code:** Standardized across all endpoints
- **Details:** Optional field for additional error-specific information (e.g., validation fields)


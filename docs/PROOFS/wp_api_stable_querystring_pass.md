# WP-NEXT: API stable query string — PASS

**Timestamp:** 2026-02-01  
**Summary:** Centralized deterministic query string builder; catalog + messaging use it; removed duplicate page-level key sorting. No backend/endpoint changes.

## Changes

### request.js
- **toStableQueryString(params):** Keys sorted lexicographically (ASCII). Skips undefined/null. Primitives → string; array → repeated key (primitives sorted for determinism); object → JSON.stringify(deepSortKeys). Output: "a=1&b=2" (no leading "?").
- **deepSortKeys(obj):** Internal helper for stable JSON key order.

### catalog.js
- **searchListings(params):** Replaced URLSearchParams(params).toString() with toStableQueryString(params). URL: `/api/v1/listings?${toStableQueryString(params)}`.

### messaging.js
- **messagingGetThreadByContext({ contextType, contextId }):** Replaced URLSearchParams with toStableQueryString({ context_type, context_id }). URL: `/api/v1/threads/by-context?${qs}`.

### ListingsSearchPage.vue
- **executeSearch:** Removed Object.keys(filterParams).sort() when merging filterParams into params; API layer now guarantees deterministic query string. Comment updated.

### RULES.md
- **Rule 72:** No force push on main. If proof needs correction after push, do follow-up commit; do not rewrite history.

## Evidence (toStableQueryString samples)

```text
toStableQueryString({ b: 2, a: 1 })           => "a=1&b=2"
toStableQueryString({ x: 'foo', y: null })   => "x=foo"   (y skipped)
toStableQueryString({ k: [3, 1, 2] })        => "k=1&k=2&k=3"  (primitives sorted)
```

## Gates

```text
.\ops\run_wp_next_local_gates.ps1   => WP-NEXT LOCAL GATES: PASS
.\ops\ops_run.ps1 -Profile Prototype => OVERALL STATUS: PASS
```

Commit: dcffff6

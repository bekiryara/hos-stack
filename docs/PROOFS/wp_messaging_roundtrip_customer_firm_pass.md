# WP-NEXT: Messaging v1 — Customer↔Firm round-trip PASS

**Timestamp:** 2026-01-31  
**Summary:** participants zorunluluğu contract’a uyumlu; firm reply mode eklendi; customer mesajı + firm cevabı aynı thread’de görünür.

## Backend contract (FIND — no change)

- **work/messaging/services/api/src/app.js**
  - POST /api/v1/threads/upsert: `participants` z.array(...).min(1) zorunlu (satır 90–93).
  - Participant type: z.enum(["user", "tenant"]) (satır 90).
  - POST .../messages: sender_type z.enum(["user", "tenant"]) (satır 151).

## Changes (marketplace-web)

- **MessagingPage.vue:** mode = query.as === 'firm' ? 'firm' : 'customer'; role-aware sender (user+userId / tenant+activeTenantId); participants upsert’e uygun (customer: user + optional listing tenant_id; firm: tenant); mine = (message.sender_type === senderType && message.sender_id === senderId); header "Message Seller" / "Reply to Customer"; Thread id debug; firm mode’da active tenant yoksa /account?reason=firm_required.
- **FirmListingsPanel.vue:** "Messages" link → `/listing/${id}/message?as=firm`.
- **ListingDetailPage.vue:** "Message Seller" → `/listing/${id}/message?as=customer` (+ tenant_id query if listing.tenant_id).

## UI steps (kanıt)

1. Customer login → listing detail → Message Seller → mesaj yaz ("customer msg") → gönder.
2. Firm login + aktif tenant → Firm Portal → aynı listing row "Messages" → "Reply to Customer" → cevap yaz ("firm reply") → gönder.
3. Customer aynı listing → Message Seller → thread’de hem customer msg hem firm reply görünür.

## Gates evidence

```text
.\ops\run_wp_next_local_gates.ps1   => === WP-NEXT LOCAL GATES: PASS ===
.\ops\ops_run.ps1 -Profile Prototype => OVERALL STATUS: PASS
```

**Commit:** `00610cc` — WP-NEXT: Messaging v1 — customer-firm roundtrip PASS

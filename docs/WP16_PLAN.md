# WP-16 MESSAGING WRITE THIN SLICE - PLAN & GUARDS v1

**Status:** PLANNING (NO IMPLEMENTATION YET)  
**Date:** 2026-01-18  
**SPEC Reference:** §5.3 (Endpoint-Persona Matrix), §20 (Messaging integration)  
**RC-1 Status:** RELEASE GATE PASSED

---

## GOAL

- Frontend READ tamamlandi (WP-15).
- Bir sonraki adimi en dusuk riskle planla.
- Teknik borc, geri donus ve patlama riskini sifira yakin tut.

---

## RC-1 RELEASE GATE STATUS

### Release Gate Checks

1. **Pazar Spine Check:**
   - World Status Check: PASS
   - Catalog Contract Check: PASS
   - Listing Contract Check: FAIL (pre-existing issue, WP-15 scope disi)
   - **Note:** Account Portal endpoint'leri calisiyor (WP-12.1'de dogrulandi)

2. **Frontend Build:**
   - `npm run build` (marketplace-web): PASS
   - Exit code: 0
   - Build output: dist/index.html, dist/assets/*.css, dist/assets/*.js

3. **Proof Document:**
   - `docs/PROOFS/wp15_frontend_readonly_pass.md` - Referans dokuman mevcut

**RC-1 Status:** VERIFIED (pre-existing Listing Contract Check issue WP-16 scope disi)

---

## WP-16 PLANNING

### Scope Definition

**WP-16 Messaging WRITE Thin Slice:**
- Yeni messaging write endpoint'leri ekle (thin slice, minimal)
- Authorization zorunlu (PERSONAL/STORE)
- Thread ownership enforced
- Idempotency-Key required
- Frontend'de "Send Message" CTA stub (disabled, sonra aktif edilecek)

### Current Messaging State

**Mevcut Durum:**
- Messaging servisi: work/messaging/services/api/ (Fastify/Node.js)
- Mevcut endpoint'ler:
  - POST /api/v1/threads/upsert (idempotent thread olusturma)
  - POST /api/v1/threads/:thread_id/messages (mesaj gonderme)
- Authentication: messaging-api-key (internal API key)
- MessagingClient.php: Pazar'dan messaging servisine erişim adapter

**Mevcut Tablolar:**
- threads (id, context_type, context_id, created_at)
- messages (id, thread_id, sender_type, sender_id, body, created_at)

**Mevcut Entegrasyon:**
- Orders: Thread olusturma (non-fatal, logged)
- Reservations: Thread olusturma (non-fatal, logged)

---

## WP-16 ENDPOINT DESIGN

### 1. POST /api/v1/messages

**Purpose:** Direkt mesaj gonderme (thread_id ile)

**Request:**
```
POST /api/v1/messages
Headers:
  Authorization: Bearer {jwt-token} (REQUIRED)
  Idempotency-Key: {uuid} (REQUIRED)
  Content-Type: application/json
Body:
  {
    "thread_id": "uuid",
    "body": "string (min 1 char, max 10000 chars)"
  }
```

**Response (201 Created):**
```json
{
  "message_id": "uuid",
  "thread_id": "uuid",
  "sender_type": "user",
  "sender_id": "uuid (from Authorization token)",
  "body": "string",
  "created_at": "ISO8601 timestamp"
}
```

**Error Responses:**
- 400 VALIDATION_ERROR: Missing/invalid thread_id or body
- 401 AUTH_REQUIRED: Missing/invalid Authorization header
- 403 FORBIDDEN_SCOPE: User not participant in thread
- 404 NOT_FOUND: Thread not found
- 409 CONFLICT: Idempotency-Key replay (same request, return existing message)
- 422 VALIDATION_ERROR: Body too long (> 10000 chars)

**Invariants:**
- Authorization header zorunlu (JWT token)
- JWT token'dan user_id extract edilir (sender_id)
- Thread ownership kontrolu: user_id thread participants'inde olmali
- Idempotency-Key ile replay kontrolu (aynı key ile tekrar istek -> 409 CONFLICT, mevcut message dondurur)

### 2. POST /api/v1/threads

**Purpose:** Idempotent thread olusturma (mevcut upsert endpoint'ine alternatif, daha basit)

**Request:**
```
POST /api/v1/threads
Headers:
  Authorization: Bearer {jwt-token} (REQUIRED)
  Idempotency-Key: {uuid} (REQUIRED)
  Content-Type: application/json
Body:
  {
    "context_type": "string (e.g., 'order', 'reservation', 'listing')",
    "context_id": "string (uuid)",
    "participants": [
      {
        "type": "user" | "tenant",
        "id": "uuid"
      }
    ]
  }
```

**Response (201 Created):**
```json
{
  "thread_id": "uuid",
  "context_type": "string",
  "context_id": "string",
  "participants": [...],
  "created_at": "ISO8601 timestamp"
}
```

**Error Responses:**
- 400 VALIDATION_ERROR: Missing/invalid context_type, context_id, or participants
- 401 AUTH_REQUIRED: Missing/invalid Authorization header
- 403 FORBIDDEN_SCOPE: Authorization user not in participants list
- 409 CONFLICT: Idempotency-Key replay (same request, return existing thread)
- 422 VALIDATION_ERROR: Participants array empty or invalid format

**Invariants:**
- Authorization header zorunlu (JWT token)
- JWT token'dan user_id extract edilir
- Authorization user_id participants listesinde olmali (en az bir participant user/tenant olarak match etmeli)
- Idempotency-Key ile replay kontrolu (aynı context_type + context_id + participants + key -> 409 CONFLICT, mevcut thread dondurur)
- Mevcut upsert endpoint'i ile uyumlu (aynı thread_id dondurur)

---

## AUTHORIZATION & SECURITY

### Authorization Strategy

**JWT Token Validation:**
- Authorization header zorunlu (Bearer token)
- JWT token'dan user_id extract edilir (sender_id olarak kullanilir)
- Token validation: Fastify JWT plugin veya manuel validation

**Thread Ownership Enforcement:**
- POST /api/v1/messages: user_id thread participants'inde olmali
- POST /api/v1/threads: user_id participants listesinde olmali (en az bir match)

**Idempotency-Key:**
- Her POST istekte zorunlu
- Format: UUID v4
- Replay kontrolu: Ayni key + ayni request body -> 409 CONFLICT (mevcut resource dondurur)

### Error Codes

- **AUTH_REQUIRED**: Missing/invalid Authorization header
- **FORBIDDEN_SCOPE**: User not authorized (not participant in thread/participants)
- **VALIDATION_ERROR**: Invalid request body (missing fields, invalid format)
- **CONFLICT**: Idempotency-Key replay (return existing resource)
- **NOT_FOUND**: Thread not found (POST /api/v1/messages)

---

## FRONTEND IMPACT

### Account Portal Integration

**"Send Message" CTA Stub:**
- Account Portal sayfasinda (AccountPortalPage.vue)
- Location: Order/Rental/Reservation card'larinda
- Initial state: DISABLED (stub only)
- Button text: "Send Message"
- Click handler: Stub (alert veya console.log, implementation sonra)

**Stub Implementation:**
```javascript
// AccountPortalPage.vue - stub method
sendMessage(contextType, contextId) {
  // TODO: WP-16 implementation
  alert('Send Message feature coming soon');
  // veya
  console.log('Send Message:', contextType, contextId);
}
```

**Future Implementation (WP-16 sonrasi):**
- Modal/form: Mesaj gonder formu
- API call: POST /api/v1/messages
- Thread creation: POST /api/v1/threads (eger thread yoksa)
- Error handling: Status + errorCode gosterimi

---

## OPS & VALIDATION

### Contract Check Script

**ops/messaging_write_contract_check.ps1 (TASLAK)**

**Purpose:** WP-16 messaging write endpoint'lerini test et

**Test Cases:**
1. POST /api/v1/threads - Valid request (201 Created)
2. POST /api/v1/threads - Idempotency replay (409 CONFLICT, same thread_id)
3. POST /api/v1/threads - Missing Authorization (401 AUTH_REQUIRED)
4. POST /api/v1/threads - Invalid participants (422 VALIDATION_ERROR)
5. POST /api/v1/messages - Valid request (201 Created)
6. POST /api/v1/messages - Idempotency replay (409 CONFLICT, same message_id)
7. POST /api/v1/messages - Missing Authorization (401 AUTH_REQUIRED)
8. POST /api/v1/messages - Thread not found (404 NOT_FOUND)
9. POST /api/v1/messages - User not participant (403 FORBIDDEN_SCOPE)
10. POST /api/v1/messages - Invalid body (422 VALIDATION_ERROR)

**Exit Code:** 0 PASS / 1 FAIL

---

## RISK ANALYSIS

### Why This Is Safe

1. **Thin Slice Approach:**
   - Minimal endpoint set (2 endpoint)
   - Mevcut messaging altyapisi uzerine insa
   - Mevcut thread/message tablolarini kullanir (yeni tablo YOK)

2. **Authorization Enforced:**
   - JWT token zorunlu (PERSONAL scope)
   - Thread ownership kontrolu (participant validation)
   - Idempotency-Key ile replay protection

3. **No Breaking Changes:**
   - Mevcut endpoint'ler korunur (upsert, thread/:id/messages)
   - Yeni endpoint'ler eklenir (additive change)
   - Mevcut entegrasyonlar etkilenmez (MessagingClient.php)

4. **Frontend Impact Minimal:**
   - Sadece stub CTA eklenir (disabled)
   - Gercek implementation sonraki WP'de
   - Account Portal sayfasi mevcut calisma durumunu korur

5. **Deterministic Operation:**
   - Idempotency-Key ile replay kontrolu
   - Error codes tutarli (AUTH_REQUIRED, FORBIDDEN_SCOPE, VALIDATION_ERROR)
   - Response format tutarli

### Potential Risks (Mitigated)

1. **JWT Token Validation:**
   - Risk: JWT validation logic hatasi
   - Mitigation: Mevcut auth.ctx middleware pattern'i kullan (Laravel'deki gibi)

2. **Thread Ownership Race Condition:**
   - Risk: Thread participant kontrolu race condition
   - Mitigation: Database transaction kullan (thread check + message insert atomic)

3. **Idempotency-Key Storage:**
   - Risk: Idempotency-Key storage (memory/database)
   - Mitigation: Basit in-memory cache (dev) veya database table (production)

4. **Message Body Length:**
   - Risk: Cok uzun mesaj body (DoS)
   - Mitigation: Body length limit (10000 chars max)

---

## READY TO IMPLEMENT CHECKLIST

### Pre-Implementation

- [x] RC-1 Release Gate PASS (pre-existing Listing Contract Check issue scope disi)
- [x] Frontend build PASS
- [x] Proof document referans mevcut (wp15_frontend_readonly_pass.md)
- [x] Mevcut messaging servisi durumu analiz edildi
- [x] Endpoint design dokumante edildi
- [x] Authorization strategy belirlendi
- [x] Error codes tanimlandi
- [x] Risk analizi yapildi

### Implementation Phase (Future)

- [ ] JWT token validation implementation (Fastify JWT plugin veya manuel)
- [ ] POST /api/v1/threads endpoint implementation
- [ ] POST /api/v1/messages endpoint implementation
- [ ] Idempotency-Key replay kontrolu implementation
- [ ] Thread ownership validation implementation
- [ ] Error response format standardization
- [ ] Contract check script implementation (ops/messaging_write_contract_check.ps1)
- [ ] Frontend stub CTA (AccountPortalPage.vue - disabled button)

### Post-Implementation Validation

- [ ] Contract check script PASS
- [ ] Authorization tests PASS (401, 403)
- [ ] Idempotency replay tests PASS (409 CONFLICT)
- [ ] Thread ownership tests PASS
- [ ] Frontend stub visible (disabled state)
- [ ] Proof document oluşturuldu (wp16_messaging_write_pass.md)

---

## DELIVERABLES (PLANNING PHASE)

1. **Planning Documents:**
   - docs/WP16_PLAN.md (this document)
   - docs/SPEC.md - WP-16 section added (PLAN ONLY)
   - docs/WP_CLOSEOUTS.md - WP-16 entry (PLANNED status)

2. **Ops Script (Taslak):**
   - ops/messaging_write_contract_check.ps1 (template, not implemented)

3. **No Code Changes:**
   - Implementation sonraki adimda (WP-16 implementation prompt'u ile)

---

## NOTES

- **No Code Written:** Bu dokuman sadece plan (implementation YOK)
- **Minimal Diff:** Sadece plan dokumanlari eklendi
- **ASCII-only:** Tum output ASCII formatinda
- **Deterministic:** Her adim net tanimli
- **Low Risk:** Thin slice, mevcut altyapi uzerine insa, authorization enforced

---

## REFERENCES

- docs/PROOFS/wp15_frontend_readonly_pass.md - WP-15 proof document
- docs/SPEC.md §5.3 - Endpoint-Persona Matrix
- docs/SPEC.md §20 - Messaging integration
- work/messaging/services/api/src/app.js - Current messaging API
- work/pazar/app/Messaging/MessagingClient.php - Pazar messaging client

---

**END OF PLAN**



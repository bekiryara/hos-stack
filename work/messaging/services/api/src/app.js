import Fastify from "fastify";
import helmet from "@fastify/helmet";
import rateLimit from "@fastify/rate-limit";
import pino from "pino";
import { z } from "zod";
import crypto from "node:crypto";

export async function buildApp({ db, logStream } = {}) {
  if (!db) throw new Error("buildApp requires db");

  const logger = pino(
    {
      level: process.env.LOG_LEVEL || "info"
    },
    logStream
  );

  const app = Fastify({
    loggerInstance: logger,
    requestIdHeader: "x-request-id",
    genReqId: (req) => {
      const headerId = req.headers["x-request-id"];
      if (typeof headerId === "string" && headerId.length >= 8 && headerId.length <= 200) return headerId;
      return crypto.randomUUID();
    },
    bodyLimit: 1 * 1024 * 1024 // 1 MiB
  });

  await app.register(helmet, {
    contentSecurityPolicy: false
  });

  await app.register(rateLimit, {
    global: true,
    max: 200,
    timeWindow: "1 minute"
  });

  app.addHook("onSend", async (_req, reply, payload) => {
    if (reply.id) reply.header("x-request-id", String(reply.id));
    return payload;
  });

  // Health endpoints
  app.get("/health", async () => ({ ok: true }));

  app.get("/ready", async (_req, reply) => {
    try {
      await db.query("select 1");
      return { ok: true };
    } catch {
      return reply.code(503).send({ ok: false });
    }
  });

  // World status endpoint (SPEC §24.4)
  app.get("/api/world/status", async (_req, reply) => {
    const version = String(process.env.MESSAGING_VERSION ?? "1.4.0").trim();
    const phase = "GENESIS";
    const commit = process.env.GIT_COMMIT ? String(process.env.GIT_COMMIT).substring(0, 7) : null;

    const response = {
      world_key: "messaging",
      availability: "ONLINE",
      phase,
      version
    };

    if (commit) response.commit = commit;

    return reply.send(response);
  });

  // Internal API key middleware
  async function requireApiKey(req, reply) {
    const apiKey = req.headers["messaging-api-key"] || req.headers["x-messaging-api-key"];
    const expectedKey = process.env.MESSAGING_API_KEY || "dev-messaging-key";

    if (apiKey !== expectedKey) {
      return reply.code(401).send({
        error: "unauthorized",
        message: "Invalid or missing MESSAGING_API_KEY header"
      });
    }
  }

  // JWT validation middleware (WP-16)
  function verifyJWT(token, secret) {
    const parts = token.split(".");
    if (parts.length !== 3) {
      throw new Error("Invalid token format");
    }

    // Decode payload (base64url decode)
    const payloadB64 = parts[1];
    const payloadB64Padded = payloadB64.replace(/-/g, "+").replace(/_/g, "/");
    const padding = "=".repeat((4 - (payloadB64Padded.length % 4)) % 4);
    const payloadJson = Buffer.from(payloadB64Padded + padding, "base64").toString("utf8");
    const payload = JSON.parse(payloadJson);

    // Verify expiration
    if (payload.exp && payload.exp < Math.floor(Date.now() / 1000)) {
      throw new Error("Token expired");
    }

    // Verify signature (HMAC-SHA256)
    const headerB64 = parts[0];
    const signatureB64 = parts[2];
    const data = headerB64 + "." + payloadB64;
    const expectedSignature = crypto.createHmac("sha256", secret).update(data).digest("base64url");
    
    if (expectedSignature !== signatureB64) {
      throw new Error("Invalid signature");
    }

    return payload;
  }

  // Require Authorization header (JWT) middleware (WP-16)
  async function requireAuth(req, reply) {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return reply.code(401).send({
        error: "AUTH_REQUIRED",
        message: "Missing or invalid Authorization header"
      });
    }

    const token = authHeader.substring(7);
    const jwtSecret = process.env.HOS_JWT_SECRET || process.env.JWT_SECRET;
    
    if (!jwtSecret || jwtSecret.length < 32) {
      return reply.code(500).send({
        error: "VALIDATION_ERROR",
        message: "JWT secret not configured (HOS_JWT_SECRET or JWT_SECRET required)"
      });
    }

    try {
      const payload = verifyJWT(token, jwtSecret);
      const userId = payload.sub || payload.user_id;
      
      if (!userId) {
        return reply.code(401).send({
          error: "VALIDATION_ERROR",
          message: "Token payload missing user identifier (sub or user_id)"
        });
      }

      req.userId = userId;
      return;
    } catch (e) {
      return reply.code(401).send({
        error: "AUTH_REQUIRED",
        message: `Invalid or expired token: ${e.message}`
      });
    }
  }

  // Require Idempotency-Key header middleware (WP-16)
  function requireIdempotencyKey(req, reply) {
    const key = req.headers["idempotency-key"] || req.headers["x-idempotency-key"];
    if (!key) {
      return reply.code(400).send({
        error: "VALIDATION_ERROR",
        message: "Missing Idempotency-Key header"
      });
    }
    req.idempotencyKey = key;
    return;
  }

  // Hash function for idempotency key storage (WP-16)
  function hashIdempotencyKey(key, resourceType, requestBody) {
    const data = `${key}:${resourceType}:${JSON.stringify(requestBody)}`;
    return crypto.createHash("sha256").update(data).digest("hex");
  }

  // POST /api/v1/threads/upsert - Upsert thread by context
  const upsertThreadSchema = z.object({
    context_type: z.string().min(1),
    context_id: z.string().min(1),
    participants: z.array(z.object({
      type: z.enum(["user", "tenant"]),
      id: z.string().min(1)
    })).min(1)
  });

  app.post("/api/v1/threads/upsert", {
    preHandler: requireApiKey
  }, async (req, reply) => {
    const parsed = upsertThreadSchema.safeParse(req.body);
    if (!parsed.success) {
      return reply.code(400).send({
        error: "validation_error",
        message: "Invalid request body",
        details: parsed.error.errors
      });
    }

    const { context_type, context_id, participants } = parsed.data;

    const client = await db.connect();
    try {
      await client.query("begin");

      // Upsert thread
      const threadRes = await client.query(`
        insert into threads (context_type, context_id)
        values ($1, $2)
        on conflict (context_type, context_id) do update
        set context_type = excluded.context_type
        returning id
      `, [context_type, context_id]);

      const threadId = threadRes.rows[0].id;

      // Upsert participants (ensure unique)
      for (const participant of participants) {
        await client.query(`
          insert into participants (thread_id, participant_type, participant_id)
          values ($1, $2, $3)
          on conflict (thread_id, participant_type, participant_id) do nothing
        `, [threadId, participant.type, participant.id]);
      }

      await client.query("commit");

      return reply.code(200).send({
        thread_id: threadId,
        context_type,
        context_id
      });
    } catch (e) {
      await client.query("rollback");
      throw e;
    } finally {
      client.release();
    }
  });

  // POST /api/v1/threads/{thread_id}/messages - Post message
  const postMessageSchema = z.object({
    sender_type: z.enum(["user", "tenant"]),
    sender_id: z.string().min(1),
    body: z.string().min(1)
  });

  app.post("/api/v1/threads/:thread_id/messages", {
    preHandler: requireApiKey
  }, async (req, reply) => {
    const { thread_id } = req.params;
    const parsed = postMessageSchema.safeParse(req.body);
    
    if (!parsed.success) {
      return reply.code(400).send({
        error: "validation_error",
        message: "Invalid request body",
        details: parsed.error.errors
      });
    }

    // Verify thread exists
    const threadRes = await db.query("select id from threads where id = $1", [thread_id]);
    if (threadRes.rowCount === 0) {
      return reply.code(404).send({
        error: "thread_not_found",
        message: `Thread with id ${thread_id} not found`
      });
    }

    const { sender_type, sender_id, body } = parsed.data;

    const msgRes = await db.query(`
      insert into messages (thread_id, sender_type, sender_id, body)
      values ($1, $2, $3, $4)
      returning id, created_at
    `, [thread_id, sender_type, sender_id, body]);

    const message = msgRes.rows[0];

    return reply.code(201).send({
      message_id: message.id,
      thread_id,
      sender_type,
      sender_id,
      body,
      created_at: message.created_at
    });
  });

  // POST /api/v1/threads - Idempotent thread creation (WP-16)
  const createThreadSchema = z.object({
    context_type: z.string().min(1),
    context_id: z.string().min(1),
    participants: z.array(z.object({
      type: z.enum(["user", "tenant"]),
      id: z.string().min(1)
    })).min(1)
  });

  app.post("/api/v1/threads", {
    preHandler: [requireAuth, requireIdempotencyKey]
  }, async (req, reply) => {
    const parsed = createThreadSchema.safeParse(req.body);
    if (!parsed.success) {
      return reply.code(400).send({
        error: "VALIDATION_ERROR",
        message: "Invalid request body",
        details: parsed.error.errors
      });
    }

    const { context_type, context_id, participants } = parsed.data;
    const userId = req.userId;
    const idempotencyKey = req.idempotencyKey;

    // Check if Authorization user is in participants
    const userInParticipants = participants.some(p => 
      (p.type === "user" && p.id === userId) || 
      (p.type === "tenant" && p.id === userId)
    );
    if (!userInParticipants) {
      return reply.code(403).send({
        error: "FORBIDDEN_SCOPE",
        message: "Authorization user not in participants list"
      });
    }

    // Check idempotency replay
    const keyHash = hashIdempotencyKey(idempotencyKey, "thread", { context_type, context_id, participants });
    const existingRes = await db.query(
      "select resource_id from idempotency_keys where key_hash = $1",
      [keyHash]
    );

    if (existingRes.rowCount > 0) {
      // Replay: return existing thread
      const threadId = existingRes.rows[0].resource_id;
      const threadRes = await db.query(
        "select id, context_type, context_id, created_at from threads where id = $1",
        [threadId]
      );
      
      if (threadRes.rowCount > 0) {
        const thread = threadRes.rows[0];
        const participantsRes = await db.query(
          "select participant_type, participant_id from participants where thread_id = $1",
          [threadId]
        );
        
        return reply.code(409).send({
          error: "CONFLICT",
          message: "Idempotency-Key replay detected",
          thread_id: thread.id,
          context_type: thread.context_type,
          context_id: thread.context_id,
          participants: participantsRes.rows.map(r => ({ type: r.participant_type, id: r.participant_id })),
          created_at: thread.created_at
        });
      }
    }

    // Create thread
    const client = await db.connect();
    try {
      await client.query("begin");

      const threadRes = await client.query(`
        insert into threads (context_type, context_id)
        values ($1, $2)
        on conflict (context_type, context_id) do update
        set context_type = excluded.context_type
        returning id, created_at
      `, [context_type, context_id]);

      const threadId = threadRes.rows[0].id;

      // Upsert participants
      for (const participant of participants) {
        await client.query(`
          insert into participants (thread_id, participant_type, participant_id)
          values ($1, $2, $3)
          on conflict (thread_id, participant_type, participant_id) do nothing
        `, [threadId, participant.type, participant.id]);
      }

      // Store idempotency key
      await client.query(`
        insert into idempotency_keys (key_hash, resource_type, resource_id, request_hash)
        values ($1, $2, $3, $4)
        on conflict (key_hash) do nothing
      `, [keyHash, "thread", threadId, keyHash]);

      await client.query("commit");

      const participantsRes = await client.query(
        "select participant_type, participant_id from participants where thread_id = $1",
        [threadId]
      );

      return reply.code(201).send({
        thread_id: threadId,
        context_type,
        context_id,
        participants: participantsRes.rows.map(r => ({ type: r.participant_type, id: r.participant_id })),
        created_at: threadRes.rows[0].created_at
      });
    } catch (e) {
      await client.query("rollback");
      throw e;
    } finally {
      client.release();
    }
  });

  // POST /api/v1/messages - Direct message send (WP-16)
  const createMessageSchema = z.object({
    thread_id: z.string().uuid(),
    body: z.string().min(1).max(10000)
  });

  app.post("/api/v1/messages", {
    preHandler: [requireAuth, requireIdempotencyKey]
  }, async (req, reply) => {
    const parsed = createMessageSchema.safeParse(req.body);
    if (!parsed.success) {
      return reply.code(400).send({
        error: "VALIDATION_ERROR",
        message: "Invalid request body",
        details: parsed.error.errors
      });
    }

    const { thread_id, body } = parsed.data;
    const userId = req.userId;
    const idempotencyKey = req.idempotencyKey;

    // Check idempotency replay
    const keyHash = hashIdempotencyKey(idempotencyKey, "message", { thread_id, body });
    const existingRes = await db.query(
      "select resource_id from idempotency_keys where key_hash = $1",
      [keyHash]
    );

    if (existingRes.rowCount > 0) {
      // Replay: return existing message
      const messageId = existingRes.rows[0].resource_id;
      const messageRes = await db.query(
        "select id, thread_id, sender_type, sender_id, body, created_at from messages where id = $1",
        [messageId]
      );
      
      if (messageRes.rowCount > 0) {
        const message = messageRes.rows[0];
        return reply.code(409).send({
          error: "CONFLICT",
          message: "Idempotency-Key replay detected",
          message_id: message.id,
          thread_id: message.thread_id,
          sender_type: message.sender_type,
          sender_id: message.sender_id,
          body: message.body,
          created_at: message.created_at
        });
      }
    }

    // Verify thread exists and user is participant
    const threadRes = await db.query("select id from threads where id = $1", [thread_id]);
    if (threadRes.rowCount === 0) {
      return reply.code(404).send({
        error: "NOT_FOUND",
        message: `Thread with id ${thread_id} not found`
      });
    }

    const participantsRes = await db.query(
      "select participant_type, participant_id from participants where thread_id = $1",
      [thread_id]
    );
    
    const userIsParticipant = participantsRes.rows.some(p => 
      (p.participant_type === "user" && p.participant_id === userId) ||
      (p.participant_type === "tenant" && p.participant_id === userId)
    );

    if (!userIsParticipant) {
      return reply.code(403).send({
        error: "FORBIDDEN_SCOPE",
        message: "User not participant in thread"
      });
    }

    // Create message
    const client = await db.connect();
    try {
      await client.query("begin");

      const msgRes = await client.query(`
        insert into messages (thread_id, sender_type, sender_id, body)
        values ($1, $2, $3, $4)
        returning id, created_at
      `, [thread_id, "user", userId, body]);

      const message = msgRes.rows[0];

      // Store idempotency key
      await client.query(`
        insert into idempotency_keys (key_hash, resource_type, resource_id, request_hash)
        values ($1, $2, $3, $4)
        on conflict (key_hash) do nothing
      `, [keyHash, "message", message.id, keyHash]);

      await client.query("commit");

      return reply.code(201).send({
        message_id: message.id,
        thread_id,
        sender_type: "user",
        sender_id: userId,
        body,
        created_at: message.created_at
      });
    } catch (e) {
      await client.query("rollback");
      throw e;
    } finally {
      client.release();
    }
  });

  // GET /api/v1/threads/by-context - Get thread by context
  app.get("/api/v1/threads/by-context", {
    preHandler: requireApiKey
  }, async (req, reply) => {
    const { context_type, context_id } = req.query;

    if (!context_type || !context_id) {
      return reply.code(400).send({
        error: "validation_error",
        message: "context_type and context_id query parameters are required"
      });
    }

    const threadRes = await db.query(`
      select id, context_type, context_id, created_at
      from threads
      where context_type = $1 and context_id = $2
      limit 1
    `, [context_type, context_id]);

    if (threadRes.rowCount === 0) {
      return reply.code(404).send({
        error: "thread_not_found",
        message: `Thread with context_type=${context_type}, context_id=${context_id} not found`
      });
    }

    const thread = threadRes.rows[0];

    // Get participants
    const participantsRes = await db.query(`
      select participant_type, participant_id, joined_at
      from participants
      where thread_id = $1
      order by joined_at
    `, [thread.id]);

    // Get last 20 messages
    const messagesRes = await db.query(`
      select id, sender_type, sender_id, body, created_at
      from messages
      where thread_id = $1
      order by created_at desc
      limit 20
    `, [thread.id]);

    return reply.send({
      thread_id: thread.id,
      context_type: thread.context_type,
      context_id: thread.context_id,
      created_at: thread.created_at,
      participants: participantsRes.rows.map(r => ({
        type: r.participant_type,
        id: r.participant_id,
        joined_at: r.joined_at
      })),
      messages: messagesRes.rows.reverse().map(r => ({
        id: r.id,
        sender_type: r.sender_type,
        sender_id: r.sender_id,
        body: r.body,
        created_at: r.created_at
      }))
    });
  });

  return app;
}





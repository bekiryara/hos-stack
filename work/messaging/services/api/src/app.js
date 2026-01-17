import Fastify from "fastify";
import helmet from "@fastify/helmet";
import rateLimit from "@fastify/rate-limit";
import pino from "pino";
import { z } from "zod";

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




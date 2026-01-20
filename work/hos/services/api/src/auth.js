import crypto from "node:crypto";
import jwt from "jsonwebtoken";
import fs from "node:fs";

const SCRYPT_N = 2 ** 15;
const SCRYPT_R = 8;
const SCRYPT_P = 1;
const KEYLEN = 32;
// Node/OpenSSL defaults can cap scrypt memory to ~32MiB; our params sit right at that boundary.
// Bump maxmem slightly to avoid "memory limit exceeded" while keeping costs bounded.
const SCRYPT_MAXMEM = 64 * 1024 * 1024; // 64 MiB

export function requireStrongJwtSecret(secret) {
  if (!secret) throw new Error("JWT_SECRET is required");
  if (secret.length < 32) throw new Error("JWT_SECRET must be at least 32 characters");
}

function getJwtSecret() {
  const direct = process.env.JWT_SECRET;
  if (direct && direct.length > 0) return direct;

  const filePath = process.env.JWT_SECRET_FILE;
  if (!filePath) return undefined;
  try {
    return fs.readFileSync(filePath, "utf8").trim();
  } catch {
    return undefined;
  }
}

export function hashPassword(password) {
  const salt = crypto.randomBytes(16);
  const hash = crypto.scryptSync(password, salt, KEYLEN, {
    N: SCRYPT_N,
    r: SCRYPT_R,
    p: SCRYPT_P,
    maxmem: SCRYPT_MAXMEM
  });
  return `scrypt$${SCRYPT_N}$${SCRYPT_R}$${SCRYPT_P}$${salt.toString("base64")}$${hash.toString("base64")}`;
}

export function verifyPassword(password, stored) {
  const parts = String(stored).split("$");
  if (parts.length !== 6) return false;
  const [alg, nStr, rStr, pStr, saltB64, hashB64] = parts;
  if (alg !== "scrypt") return false;

  const N = Number(nStr);
  const r = Number(rStr);
  const p = Number(pStr);
  if (!Number.isFinite(N) || !Number.isFinite(r) || !Number.isFinite(p)) return false;

  const salt = Buffer.from(saltB64, "base64");
  const expected = Buffer.from(hashB64, "base64");
  const actual = crypto.scryptSync(password, salt, expected.length, { N, r, p, maxmem: SCRYPT_MAXMEM });
  return crypto.timingSafeEqual(expected, actual);
}

export function signAccessToken(payload) {
  const secret = getJwtSecret();
  requireStrongJwtSecret(secret);
  return jwt.sign(payload, secret, { algorithm: "HS256", expiresIn: "15m" });
}

export function verifyAccessToken(token) {
  const secret = getJwtSecret();
  requireStrongJwtSecret(secret);
  return jwt.verify(token, secret, { algorithms: ["HS256"] });
}



// Signed, non-expiring links for "stop emailing me". No database lookup is needed to check one: the link
// carries the address and a signature only this server can make, so nobody can opt another address out by guessing.

const enc = new TextEncoder();

function b64url(bytes: Uint8Array): string {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function fromB64url(s: string): Uint8Array {
  const pad = "=".repeat((4 - (s.length % 4)) % 4);
  const bin = atob(s.replace(/-/g, "+").replace(/_/g, "/") + pad);
  return Uint8Array.from(bin, (c) => c.charCodeAt(0));
}

async function sign(secret: string, email: string): Promise<Uint8Array> {
  const key = await crypto.subtle.importKey("raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return new Uint8Array(await crypto.subtle.sign("HMAC", key, enc.encode(`unsubscribe:${email}`)));
}

export async function makeUnsubscribeToken(secret: string, email: string): Promise<string> {
  if (!secret) throw new Error("UNSUBSCRIBE_SECRET is not set");
  const e = email.trim().toLowerCase();
  return `${b64url(enc.encode(e))}.${b64url(await sign(secret, e))}`;
}

/** The address a valid token was made for, or null if the token is malformed or its signature does not match. */
export async function verifyUnsubscribeToken(secret: string, token: string): Promise<string | null> {
  if (!secret || typeof token !== "string") return null;
  const parts = token.split(".");
  if (parts.length !== 2 || !parts[0] || !parts[1] || token.length > 600) return null;
  try {
    const email = new TextDecoder().decode(fromB64url(parts[0]));
    if (!email || email !== email.toLowerCase() || !/^[^\s@]+@[^\s@]+$/.test(email)) return null;
    const expected = await sign(secret, email);
    const given = fromB64url(parts[1]);
    if (given.length !== expected.length) return null;
    let diff = 0;
    for (let i = 0; i < expected.length; i++) diff |= expected[i] ^ given[i];
    return diff === 0 ? email : null;
  } catch (_) {
    return null;
  }
}

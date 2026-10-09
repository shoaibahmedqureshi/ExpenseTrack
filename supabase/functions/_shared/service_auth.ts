// Back-office functions (the agents, approvals, test sends) are only meant to be called by our own scheduled jobs, which send
// the project's service-role key. The public anon key is also a valid JWT, so "has a valid JWT" is not enough: require the
// service-role identity. Deploy these functions with JWT verification ON (config.toml pins it) so the platform has already
// checked the token's signature; this then checks who the token says it is.

function payloadOf(token: string): Record<string, unknown> | null {
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  try {
    const b64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const json = new TextDecoder().decode(Uint8Array.from(atob(b64 + "=".repeat((4 - (b64.length % 4)) % 4)), (c) => c.charCodeAt(0)));
    const p = JSON.parse(json);
    return p && typeof p === "object" ? p : null;
  } catch (_) {
    return null;
  }
}

export function isServiceRole(authorizationHeader: string | null): boolean {
  const m = /^Bearer\s+(\S+)$/i.exec(authorizationHeader ?? "");
  if (!m) return false;
  return payloadOf(m[1])?.role === "service_role";
}

/** Returns a 403 response for anyone who is not the service role, or null when the request may go ahead. */
export function requireServiceRole(req: Request): Response | null {
  if (isServiceRole(req.headers.get("Authorization"))) return null;
  return new Response(JSON.stringify({ error: "This function is not available to apps or browsers" }), {
    status: 403,
    headers: { "Content-Type": "application/json" },
  });
}

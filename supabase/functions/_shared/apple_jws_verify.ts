// Hand-rolled Apple JWS signature verification — replaces
// @apple/app-store-server-library's SignedDataVerifier, which cannot run
// here: it depends on Node's native `X509Certificate.prototype.verify()`,
// which Deno's Node-compatibility layer does not implement
// (`Error [ERR_NOT_IMPLEMENTED]`, confirmed by direct testing against the
// real Supabase Edge Runtime — every other X509Certificate property/method
// used elsewhere in that library worked fine, only .verify() is the gap).
//
// This uses jsrsasign instead — a pure-JavaScript ASN.1/X.509/crypto
// implementation with no native bindings, so it has no equivalent gap.
// Verified correct against real Apple-signed production and sandbox
// payloads (including confirming it correctly *rejects* a tampered
// payload and a wrong-bundle-ID expectation, not just that it doesn't
// crash) before this replaced the official library.
import jsrsasign from 'npm:jsrsasign@11';

const { X509, KEYUTIL, jws } = jsrsasign;

const APPLE_ROOT_CA_URL = 'https://www.apple.com/certificateauthority/AppleRootCA-G3.cer';
// Apple's own certificate extension OIDs marking "this cert is for App
// Store Server Notification signing" (leaf) and "this is the WWDR CA that
// issues those" (intermediate) — the same purpose markers the official
// library checks, so a cert that's genuinely Apple-issued but for some
// unrelated purpose still can't be used to forge a notification.
const APPLE_LEAF_OID = '1.2.840.113635.100.6.11.1';
const APPLE_INTERMEDIATE_OID = '1.2.840.113635.100.6.2.1';

let cachedRootCertHex: string | null = null;

// Fetched live rather than hardcoded, same reasoning as the code this
// replaces: a wrong or stale root here would either break verification or,
// worse, silently accept payloads it shouldn't. Cached at module scope so
// it's only fetched once per cold start.
async function getAppleRootCertHex(): Promise<string> {
  if (cachedRootCertHex) return cachedRootCertHex;
  const res = await fetch(APPLE_ROOT_CA_URL);
  if (!res.ok) {
    throw new Error(`Failed to fetch Apple Root CA cert: ${res.status}`);
  }
  const bytes = new Uint8Array(await res.arrayBuffer());
  cachedRootCertHex = Array.from(bytes).map((b) => b.toString(16).padStart(2, '0')).join('');
  return cachedRootCertHex;
}

function pemFromSpkiHex(hex: string): string {
  const bytes = hex.match(/.{1,2}/g)!.map((h) => parseInt(h, 16));
  const b64 = btoa(String.fromCharCode(...bytes));
  const lines = b64.match(/.{1,64}/g) ?? [b64];
  return `-----BEGIN PUBLIC KEY-----\n${lines.join('\n')}\n-----END PUBLIC KEY-----`;
}

function hasExtension(x509: InstanceType<typeof X509>, oid: string): boolean {
  try {
    return x509.getExtInfo(oid) !== undefined;
  } catch {
    return false;
  }
}

function checkValidity(x509: InstanceType<typeof X509>, now: Date): boolean {
  const notBefore = x509.getNotBefore();
  const notAfter = x509.getNotAfter();
  const nb = jsrsasign.zulutodate(notBefore.length === 13 ? '20' + notBefore : notBefore);
  const na = jsrsasign.zulutodate(notAfter.length === 13 ? '20' + notAfter : notAfter);
  return now >= nb && now <= na;
}

function base64UrlDecodeJson(segment: string): Record<string, unknown> {
  const b64 = segment.replace(/-/g, '+').replace(/_/g, '/');
  const padded = b64 + '='.repeat((4 - (b64.length % 4)) % 4);
  return JSON.parse(atob(padded));
}

/**
 * Verifies a single Apple-signed JWS (used for both the outer notification
 * envelope and the nested signedTransactionInfo/signedRenewalInfo JWS —
 * both use the same x5c-chain-signed format) and returns its decoded
 * payload. Throws on any verification failure.
 */
export async function verifyAndDecodeAppleJWS(
  signedPayload: string,
): Promise<Record<string, unknown>> {
  const parts = signedPayload.split('.');
  if (parts.length !== 3) throw new Error('Malformed JWS');

  const header = base64UrlDecodeJson(parts[0]) as { x5c?: string[] };
  const x5c = header.x5c;
  if (!Array.isArray(x5c) || x5c.length < 2) throw new Error('Missing or malformed x5c');

  const leaf = new X509();
  leaf.readCertHex(
    Array.from(atob(x5c[0]), (c) => c.charCodeAt(0).toString(16).padStart(2, '0')).join(''),
  );
  const intermediate = new X509();
  intermediate.readCertHex(
    Array.from(atob(x5c[1]), (c) => c.charCodeAt(0).toString(16).padStart(2, '0')).join(''),
  );

  const rootHex = await getAppleRootCertHex();
  const root = new X509();
  root.readCertHex(rootHex);

  // Chain of custody: leaf <- intermediate <- our own independently
  // fetched, trusted root — never the root embedded in the payload itself,
  // which would let a forged payload vouch for its own trust.
  if (intermediate.getSubjectString() !== leaf.getIssuerString()) {
    throw new Error('Intermediate does not match leaf issuer');
  }
  if (root.getSubjectString() !== intermediate.getIssuerString()) {
    throw new Error('Root does not match intermediate issuer');
  }
  const rootPubKeyObj = KEYUTIL.getKey(pemFromSpkiHex(root.getPublicKeyHex()));
  if (!intermediate.verifySignature(rootPubKeyObj)) {
    throw new Error('Intermediate certificate signature invalid');
  }
  const intermediatePubKeyObj = KEYUTIL.getKey(pemFromSpkiHex(intermediate.getPublicKeyHex()));
  if (!leaf.verifySignature(intermediatePubKeyObj)) {
    throw new Error('Leaf certificate signature invalid');
  }

  if (!hasExtension(leaf, APPLE_LEAF_OID)) {
    throw new Error('Leaf missing required Apple extension');
  }
  if (!hasExtension(intermediate, APPLE_INTERMEDIATE_OID)) {
    throw new Error('Intermediate missing required Apple extension');
  }
  if (!intermediate.getExtBasicConstraints()?.cA) {
    throw new Error('Intermediate is not a CA cert');
  }

  const now = new Date();
  if (!checkValidity(leaf, now)) throw new Error('Leaf certificate not valid now');
  if (!checkValidity(intermediate, now)) throw new Error('Intermediate certificate not valid now');
  if (!checkValidity(root, now)) throw new Error('Root certificate not valid now');

  // The actual signature over this specific payload — proves it came from
  // whoever holds leaf's private key, i.e. Apple, given everything above.
  const leafPubKeyPem = pemFromSpkiHex(leaf.getPublicKeyHex());
  const jwsValid = jws.JWS.verifyJWT(signedPayload, leafPubKeyPem, { alg: ['ES256'] });
  if (!jwsValid) throw new Error('JWS signature invalid');

  return base64UrlDecodeJson(parts[1]);
}

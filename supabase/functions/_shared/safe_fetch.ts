import { isSafeUrl } from "./contact_finder.ts";

const MAX_BYTES = 1_000_000;
const UA = "Mozilla/5.0 (compatible; OutlayContactCheck/1.0; +https://outlayapp.net)";

/** GET a public https page; follows up to 3 redirects, re-checking every hop. */
export async function fetchPage(url: string): Promise<{ url: string; text: string } | null> {
  let current = url;
  for (let hop = 0; hop < 4; hop++) {
    if (!isSafeUrl(current)) return null;
    try {
      const res = await fetch(current, {
        redirect: "manual",
        headers: { "User-Agent": UA, "Accept": "text/html" },
        signal: AbortSignal.timeout(8000),
      });
      if (res.status >= 300 && res.status < 400) {
        const loc = res.headers.get("location");
        if (!loc) return null;
        current = new URL(loc, current).toString();
        continue;
      }
      if (!res.ok || !(res.headers.get("content-type") || "").includes("text/html")) return null;
      const reader = res.body?.getReader();
      if (!reader) return null;
      const chunks: Uint8Array[] = [];
      let size = 0;
      while (size < MAX_BYTES) {
        const { done, value } = await reader.read();
        if (done || !value) break;
        chunks.push(value);
        size += value.length;
      }
      reader.cancel().catch(() => {});
      return { url: current, text: new TextDecoder().decode(await new Blob(chunks).arrayBuffer()) };
    } catch {
      return null;
    }
  }
  return null;
}


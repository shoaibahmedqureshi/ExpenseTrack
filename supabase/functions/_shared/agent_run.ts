// Helpers so agent functions report failures instead of swallowing them.

/** Parses JSON from a model reply, tolerating ```json fences and surrounding prose. */
export function parseModelJson<T = unknown>(text: string): T {
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const body = (fenced ? fenced[1] : text).trim();
  try {
    return JSON.parse(body) as T;
  } catch {
    const start = body.search(/[\[{]/);
    const end = Math.max(body.lastIndexOf("]"), body.lastIndexOf("}"));
    if (start === -1 || end <= start) throw new Error("no JSON found in model reply");
    return JSON.parse(body.slice(start, end + 1)) as T;
  }
}

export interface RunStats {
  failures: string[];
  ok: number;
}

/** Runs a supabase-js write and records the failure instead of ignoring it. */
export async function checked(
  stats: RunStats,
  label: string,
  op: PromiseLike<{ error: { message: string } | null }>,
): Promise<boolean> {
  try {
    const { error } = await op;
    if (error) {
      stats.failures.push(`${label}: ${error.message}`);
      return false;
    }
    stats.ok++;
    return true;
  } catch (e) {
    stats.failures.push(`${label}: ${String(e)}`);
    return false;
  }
}

export const newStats = (): RunStats => ({ failures: [], ok: 0 });

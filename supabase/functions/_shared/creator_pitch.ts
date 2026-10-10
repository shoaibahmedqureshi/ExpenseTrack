import { offerLine } from "./blog_outreach.ts";

export const CREATOR_PAGE = "https://outlayapp.net/creators.html";

/** Phrases that claim we watched or know their content. We have only read their channel description. */
const FAMILIARITY = /\b(i|we)('ve| have)?\s+(been\s+)?(watch|watched|follow|followed|following|love|loved|enjoy|enjoyed|binge|subscrib)|your (latest|recent|last|new|most recent) (video|post|upload)|(big|huge)\s+fan|(saw|watched|loved) your (video|content|channel)/i;

export function claimsFamiliarity(text: string): boolean {
  return FAMILIARITY.test(text);
}

export interface CreatorFacts { handle: string; niche: string; subscribers: number; bio: string }

/** One grounded opening line. The model's version is used only if it makes no claim about watching them. */
export function safeOpening(modelLine: string | undefined, f: CreatorFacts): string {
  const line = (modelLine || "").replace(/\s+/g, " ").trim();
  if (line && line.length <= 220 && !claimsFamiliarity(line) && !/[<>]|https?:/i.test(line)) return line;
  return `I came across your channel, which covers ${f.niche}.`;
}

export function buildCreatorPitch(f: CreatorFacts, opening: string): { subject: string; body: string } {
  const name = f.handle.replace(/^@/, "");
  const body = [
    `Hi ${name},`,
    "",
    opening,
    "",
    `We make apps people use every day, and we'd like to give you ${offerLine()}, with no strings attached, so you can try them properly.`,
    "",
    `If you like them, we also run a creator programme where you can earn a commission on subscriptions from your audience. Details and how to apply are here: ${CREATOR_PAGE}`,
    "",
    "If this isn't for you, just reply and we won't contact you again.",
    "",
    "The Outlay team",
  ].join("\n");
  return { subject: "Free 1-year access to our apps, and a creator programme", body };
}

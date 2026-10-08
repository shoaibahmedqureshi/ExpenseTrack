const APP_STORE = "https://apps.apple.com/app/id6790199113";
const PLAY_STORE = "https://play.google.com/store/apps/details?id=com.outlay.app";

// Whatever a person typed as their name ends up in a subject line and a body, so keep it to plain text.
const plain = (s: string, max: number) => s.replace(/[\r\n\t<>]+/g, " ").replace(/\s+/g, " ").trim().slice(0, max);

export function buildInviteEmail(inviter: string, group: string, email: string, expires: Date) {
  const who = plain(inviter, 40) || "A friend";
  const name = plain(group, 60);
  const date = expires.toLocaleDateString("en-GB", { day: "numeric", month: "long", year: "numeric", timeZone: "UTC" });
  return {
    subject: `${who} invited you to "${name}" on Outlay`,
    text: [
      "Hi,",
      "",
      `${who} added you to the group "${name}" on Outlay, an app for tracking expenses and splitting costs with friends.`,
      "",
      "To join:",
      "1. Install Outlay",
      `   App Store: ${APP_STORE}`,
      `   Google Play: ${PLAY_STORE}`,
      `2. Sign up with this email address: ${email}`,
      "3. Open the Splits tab. You will see the invitation there.",
      "",
      `The invitation is open until ${date}.`,
      `If you do not know ${who}, you can ignore this message. Nothing happens unless you sign up.`,
      "",
      "Outlay",
    ].join("\n"),
  };
}

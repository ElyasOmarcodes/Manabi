// Screenshot driver for the Manabi web build (Flutter renders to canvas, so
// we enable Flutter's semantics tree and click by accessible names).
import { chromium } from "playwright";

// Usage: node shots.mjs <app-url> <out-dir> [ui|live|<prefix>]
const [, , url = "http://localhost:8080/", out = "shots", only = "ui"] = process.argv;
const LIVE = only === "live";
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined, args: ["--no-sandbox"] });

const open = async ({ width, height, lang = "ps", theme = "light", prefs = {} }) => {
  const ctx = await browser.newContext({ viewport: { width, height }, deviceScaleFactor: 2, locale: "en-US" });
  await ctx.addInitScript(([lang, theme, prefs]) => {
    localStorage.setItem("flutter.uiLanguage", JSON.stringify(lang));
    localStorage.setItem("flutter.themeMode", JSON.stringify(theme));
    for (const [k, v] of Object.entries(prefs)) localStorage.setItem(`flutter.${k}`, JSON.stringify(v));
  }, [lang, theme, prefs]);
  const page = await ctx.newPage();
  page.on("pageerror", (e) => console.error("pageerror:", e.message));
  await page.goto(url);
  return { ctx, page };
};

const semantics = async (page) => {
  await page.waitForSelector("flt-semantics-placeholder", { state: "attached", timeout: 30_000 });
  await page.evaluate(() => document.querySelector("flt-semantics-placeholder")?.click());
  await page.waitForTimeout(600);
};
const tap = async (page, name, { exact = false, nth = 0 } = {}) => {
  const deadline = Date.now() + 15_000;
  while (Date.now() < deadline) {
    const box = await page.evaluate(([name, exact, nth]) => {
      const match = (t) => (t ?? "").trim() && (exact ? (t ?? "").trim() === name : (t ?? "").includes(name));
      const all = [...document.querySelectorAll("flt-semantics")].filter((n) => match(n.getAttribute("aria-label")) || (match(n.textContent) && [...n.children].every((c) => !match(c.textContent))));
      const el = all[nth];
      if (!el) return null;
      const r = el.getBoundingClientRect();
      return r.width ? { x: r.x + r.width / 2, y: r.y + r.height / 2 } : null;
    }, [name, exact, nth]);
    if (box) {
      await page.mouse.click(box.x, box.y);
      await page.waitForTimeout(900);
      return;
    }
    await page.waitForTimeout(300);
  }
  throw new Error(`not found: ${name}`);
};
const shot = async (page, name) => {
  await page.screenshot({ path: `${out}/${name}.png` });
  console.log("saved", name);
};

const run = async (name, fn) => {
  if (name.startsWith("live") !== LIVE) return;
  if (!LIVE && only !== "ui" && !name.startsWith(only)) return;
  try {
    await fn();
  } catch (e) {
    console.error("FAILED", name, e.message.split("\n")[0]);
    process.exitCode = 1;
  }
};

await run("01", async () => {
  const { ctx, page } = await open({ width: 1440, height: 900 });
  await page.waitForTimeout(1500);
  await shot(page, "01-splash");
  await page.waitForTimeout(3500);
  await shot(page, "02-chat-welcome-desktop");
  await semantics(page);
  await tap(page, "د لټون اختیارونه");
  await page.waitForTimeout(700);
  await shot(page, "03-chat-options");
  await tap(page, "کتاب", { exact: true });
  await page.waitForTimeout(800);
  await page.keyboard.type("رياض الصالحين");
  await page.waitForTimeout(900);
  await shot(page, "04-scope-picker-book");
  await page.keyboard.press("Escape");
  await page.waitForTimeout(500);
  await page.keyboard.press("Escape");
  await page.waitForTimeout(500);
  await tap(page, "د «إنما الأعمال بالنيات» حدیث چا روایت کړی دی؟");
  await shot(page, "05-chat-composer-filled");
  await ctx.close();
});

await run("06", async () => {
  const { ctx, page } = await open({ width: 1440, height: 900 });
  await page.waitForTimeout(4000);
  await semantics(page);
  await tap(page, "کتابتون", { exact: true });
  await page.waitForTimeout(800);
  await shot(page, "06-library-books");
  await tap(page, "مؤلفین", { exact: true });
  await shot(page, "07-library-authors");
  await tap(page, "ډلې", { exact: true });
  await shot(page, "08-library-categories");
  await tap(page, "تنظیمات", { exact: true });
  await shot(page, "09-settings");
  await page.mouse.wheel(0, 900);
  await page.waitForTimeout(700);
  await shot(page, "10-settings-connection");
  await tap(page, "خوندي", { exact: true });
  await shot(page, "11-saved-empty");
  await ctx.close();
});

await run("12", async () => {
  const { ctx, page } = await open({ width: 1440, height: 900, theme: "dark" });
  await page.waitForTimeout(4000);
  await shot(page, "12-chat-welcome-dark");
  await semantics(page);
  await tap(page, "کتابتون", { exact: true });
  await shot(page, "13-library-dark");
  await ctx.close();
});

await run("14", async () => {
  const { ctx, page } = await open({ width: 390, height: 844 });
  await page.waitForTimeout(4000);
  await shot(page, "14-phone-chat");
  await semantics(page);
  await tap(page, "کتابتون", { exact: true });
  await shot(page, "15-phone-library");
  await tap(page, "تنظیمات", { exact: true });
  await shot(page, "16-phone-settings");
  await ctx.close();
});

await run("17", async () => {
  const { ctx, page } = await open({ width: 390, height: 844, theme: "dark", lang: "en" });
  await page.waitForTimeout(4000);
  await shot(page, "17-phone-dark-english");
  await semantics(page);
  await page.getByRole("button", { name: "Chats" }).click().catch(() => tap(page, "Chats"));
  await page.waitForTimeout(900);
  await shot(page, "18-phone-chat-list-drawer");
  await ctx.close();
});

const waitForAnswer = async (page, labels, timeout = 240_000) => {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    const found = await page.evaluate((labels) => {
      const texts = [...document.querySelectorAll("flt-semantics")].map((n) => `${n.getAttribute("aria-label") ?? ""} ${n.textContent ?? ""}`);
      return labels.find((l) => texts.some((t) => t.includes(l))) ?? null;
    }, labels);
    if (found) return found;
    await page.waitForTimeout(1500);
  }
  throw new Error("answer did not arrive");
};

// Real end-to-end answers: the app talks to a Manabi server that has the
// Gemini key and reaches Turath. Nothing here is mocked.
const ask = async (name, { lang, question, width = 1440, height = 900, theme = "light", done }) => {
  await run(name, async () => {
    const { ctx, page } = await open({ width, height, lang, theme, prefs: { serverUrl: process.env.MANABI_SERVER_URL ?? "http://localhost:8787", mode: "server" } });
    await page.waitForTimeout(4000);
    await semantics(page);
    await tap(page, question);
    await page.waitForTimeout(500);
    await page.keyboard.press("Enter");
    await page.waitForTimeout(2500);
    await shot(page, `${name}-progress`);
    const status = await waitForAnswer(page, done);
    console.log(name, "status:", status);
    await page.waitForTimeout(1500);
    await shot(page, `${name}-answer`);
    for (let i = 1; i <= 3; i += 1) {
      await page.mouse.move(width / 2, height / 2);
      await page.mouse.wheel(0, height * 0.7);
      await page.waitForTimeout(900);
      await shot(page, `${name}-answer-${i}`);
    }
    await ctx.close();
  });
};

await ask("live-1-ps", { lang: "ps", question: "د «إنما الأعمال بالنيات» حدیث چا روایت کړی دی؟", done: ["مستند ځواب", "په نیمګړي ډول مستند", "مستند ځواب ونه موندل شو"] });
await ask("live-2-ar", { lang: "ar", question: "ماذا تقول كتب الفقه في مس الذكر ونقض الوضوء؟", done: ["جواب موثق", "موثق جزئيًا", "لم يوجد جواب موثق"] });
await ask("live-3-en-phone", { lang: "en", theme: "dark", width: 390, height: 844, question: "What is the meaning of Ihsan in the hadith of Jibril?", done: ["Documented answer", "Partly documented", "No documented answer found"] });

await browser.close();

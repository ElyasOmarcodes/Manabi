// Screenshot driver for the Manabi web build (Flutter renders to canvas, so
// we enable Flutter's semantics tree and click by accessible names).
import { chromium } from "playwright";

// Usage: node shots.mjs <app-url> <out-dir> [ui|live|<prefix>]
const [, , url = "http://localhost:8080/", out = "shots", only = "ui"] = process.argv;
const LIVE = only === "live" || only.startsWith("live-");
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined, args: ["--no-sandbox"] });

const open = async ({ width, height, lang = "ps", theme = "light", prefs = {} }) => {
  const ctx = await browser.newContext({ viewport: { width, height }, deviceScaleFactor: 2, locale: "en-US" });
  await ctx.addInitScript(([lang, theme, prefs]) => {
    localStorage.setItem("flutter.uiLanguage", JSON.stringify(lang));
    localStorage.setItem("flutter.themeMode", JSON.stringify(theme));
    // The starter questions rotate; screenshots use the classic first ones.
    localStorage.setItem("flutter.fixedSuggestions", "true");
    // Past the first-run library setup (it has its own screenshot run).
    localStorage.setItem("flutter.librarySyncedAt", "1");
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
  if (only !== "ui" && only !== "live" && !name.startsWith(only)) return;
  try {
    await fn();
  } catch (e) {
    console.error("FAILED", name, e.message.split("\n")[0]);
    process.exitCode = 1;
  }
};

const desktop = { width: 1440, height: 900 };
const phone = { width: 390, height: 844 };

// Opens a fresh app, enables semantics and optionally opens a menu page.
const section = async (opts, label, menu = false) => {
  const { ctx, page } = await open(opts);
  await page.waitForTimeout(4000);
  await semantics(page);
  if (menu) await tap(page, menu === true ? "چټونه" : menu, { exact: true });
  if (label) {
    await tap(page, label, { exact: true });
    await page.waitForTimeout(800);
  }
  return { ctx, page };
};

await run("01", async () => {
  const { ctx, page } = await open(desktop);
  await page.waitForTimeout(1500);
  await shot(page, "01-splash");
  await page.waitForTimeout(3500);
  await shot(page, "02-chat-welcome-desktop");
  await semantics(page);
  await tap(page, "د لټون اختیارونه");
  await page.waitForTimeout(700);
  await shot(page, "03-chat-plus-sheet");
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
  const { ctx, page } = await section(phone);
  await tap(page, "د څېړنې کچه");
  await page.waitForTimeout(700);
  await shot(page, "06-phone-research-depth");
  await ctx.close();
  const p = await section(phone, "د لټون اختیارونه");
  await shot(p.page, "07-phone-plus-sheet");
  await p.ctx.close();
});

await run("08", async () => {
  const { ctx, page } = await section(desktop, "کتابتون");
  await shot(page, "08-library-home");
  await tap(page, "مؤلفین");
  await shot(page, "09-library-authors");
  await ctx.close();
});

await run("10", async () => {
  const { ctx, page } = await section(phone, "تنظیمات", true);
  await shot(page, "10-phone-settings");
  await ctx.close();
  // Rows merge title and value into one label, so match partially.
  for (const [label, name, scroll, nth] of [["بڼه", "11-phone-settings-appearance", 0, 0], ["د AI سبک", "12-phone-settings-ai-style", 0, 0], ["زموږ په اړه", "13-phone-settings-about", 600, 0], ["مرسته", "14-phone-settings-help", 600, -1]]) {
    const p = await section(phone, "تنظیمات", true);
    if (scroll) {
      await p.page.mouse.move(195, 500);
      await p.page.mouse.wheel(0, scroll);
      await p.page.waitForTimeout(500);
    }
    await tap(p.page, label, nth < 0 ? { exact: true } : { nth });
    await p.page.waitForTimeout(800);
    await shot(p.page, name);
    await p.ctx.close();
  }
  const l = await section(phone, "تنظیمات", true);
  await tap(l.page, "د اپلیکیشن ژبه");
  await shot(l.page, "15-phone-settings-language");
  await l.ctx.close();
});

await run("16", async () => {
  const dark = { ...desktop, theme: "dark" };
  const { ctx, page } = await section(dark);
  await shot(page, "16-chat-welcome-dark");
  await ctx.close();
  const s = await section(dark, "تنظیمات");
  await shot(s.page, "17-settings-dark");
  await s.ctx.close();
});

await run("18", async () => {
  const { ctx, page } = await section(phone);
  await shot(page, "18-phone-chat");
  await tap(page, "چټونه", { exact: true });
  await page.waitForTimeout(700);
  await shot(page, "19-phone-menu");
  await ctx.close();
  const l = await section(phone, "کتابتون", true);
  await shot(l.page, "20-phone-library");
  await l.ctx.close();
});

await run("21", async () => {
  const { ctx, page } = await section({ ...phone, theme: "dark", lang: "en" });
  await shot(page, "21-phone-dark-english");
  await tap(page, "Chats", { exact: true });
  await page.waitForTimeout(700);
  await shot(page, "22-phone-dark-menu");
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

// A documented answer shows its "Sources (n)" button; other outcomes show a status pill.
// Real end-to-end answers: the app talks to a Manabi server that has the
// Gemini key and reaches Turath. Nothing here is mocked.
const ask = async (name, { lang, question, typed = false, width = 1440, height = 900, theme = "light", done, sources, scrolls = 3 }) => {
  await run(name, async () => {
    const { ctx, page } = await open({ width, height, lang, theme, prefs: { serverUrl: process.env.MANABI_SERVER_URL ?? "http://localhost:8787", mode: "server" } });
    await page.waitForTimeout(4000);
    await semantics(page);
    if (typed) {
      // A question of one's own: a starter question fills the composer, then it is replaced.
      await tap(page, typed);
      await page.waitForTimeout(400);
      await page.keyboard.press("Control+A");
      await page.keyboard.type(question);
    } else {
      await tap(page, question);
    }
    await page.waitForTimeout(500);
    await page.keyboard.press("Control+Enter");
    await page.waitForTimeout(2500);
    await shot(page, `${name}-progress`);
    const status = await waitForAnswer(page, done).catch(async (error) => {
      // Keep evidence of what the app showed instead of the answer.
      await shot(page, `${name}-timeout`);
      const texts = await page.evaluate(() => [...document.querySelectorAll("flt-semantics")].map((n) => n.getAttribute("aria-label") || "").filter(Boolean).slice(-25));
      console.error(name, "visible:", JSON.stringify(texts).slice(0, 1500));
      throw error;
    });
    console.log(name, "status:", status);
    await page.waitForTimeout(1500);
    await shot(page, `${name}-answer`);
    for (let i = 1; i <= scrolls; i += 1) {
      await page.mouse.move(width / 2, height / 2);
      await page.mouse.wheel(0, height * 0.7);
      await page.waitForTimeout(900);
      await shot(page, `${name}-answer-${i}`);
    }
    if (sources) {
      await tap(page, sources).catch(() => undefined);
      await page.waitForTimeout(1200);
      await shot(page, `${name}-sources`);
    }
    await ctx.close();
  });
};

await ask("live-1-ps", { lang: "ps", question: "د «إنما الأعمال بالنيات» حدیث چا روایت کړی دی؟", done: ["منابع (", "په نیمګړي ډول مستند", "مستند ځواب ونه موندل شو"], sources: "منابع (" });
await ask("live-2-ar", { lang: "ar", question: "ماذا تقول كتب الفقه في مس الذكر ونقض الوضوء؟", done: ["المصادر (", "موثق جزئيًا", "لم يوجد جواب موثق"], sources: "المصادر (" });
await ask("live-3-en-phone", { lang: "en", theme: "dark", width: 390, height: 844, question: "Who narrated the hadith «إنما الأعمال بالنيات»?", done: ["Sources (", "Partly documented", "No documented answer found"], sources: "Sources (" });

// A scholar's view on a topic, asked as short posts with references (compared with Turath AI and Qaf).
await ask("live-5-posts", {
  lang: "ps",
  width: 390,
  height: 844,
  typed: "د «إنما الأعمال بالنيات» حدیث چا روایت کړی دی؟",
  question: "ابو حامد رحمه الله څه وایی چې توبه څومره اهمیت لري؟ د توبې په تړاو یې کوم بحث کړی؟ د توبې له مبحث یې مهم نقل قول او اقوال راته د حوالو سره ولیکه ترڅو یی اجتماعی رسنیو کی د کوچنیو پوستونو په څیر نشر کړم.",
  done: ["منابع (", "په نیمګړي ډول مستند", "مستند ځواب ونه موندل شو"],
  sources: "منابع (",
  scrolls: 8,
});

// Library and reader (needs a server: demo-server.mjs offline, or the real one).
await run("live-4-reader", async () => {
  const { ctx, page } = await open({ ...phone, prefs: { serverUrl: process.env.MANABI_SERVER_URL ?? "http://localhost:8787", mode: "server" } });
  await page.waitForTimeout(4000);
  await semantics(page);
  // Ask, open the sources, then read the cited page.
  await tap(page, "د «إنما الأعمال بالنيات» حدیث چا روایت کړی دی؟");
  await page.waitForTimeout(500);
  await page.keyboard.press("Control+Enter");
  await waitForAnswer(page, ["منابع ("]);
  await page.waitForTimeout(1200);
  await tap(page, "منابع (");
  await page.waitForTimeout(1200);
  await tap(page, "مخ لوستل");
  await page.waitForTimeout(3000);
  await shot(page, "live-4-reader");
  // The book page: its card (publisher, editor …) and its long write-up.
  await tap(page, "الأربعون النووية");
  await page.waitForTimeout(2500);
  await shot(page, "live-4-book");
  await page.mouse.move(phone.width / 2, phone.height / 2);
  await page.mouse.wheel(0, phone.height * 0.6);
  await page.waitForTimeout(900);
  await shot(page, "live-4-book-2");
  await page.goBack().catch(() => undefined);
  await tap(page, "شاته").catch(() => page.keyboard.press("Escape"));
  await page.waitForTimeout(1200);
  // In-book search and contents (on a phone the tools sit on the bar's other page).
  try {
    await tap(page, "په کتاب کې لټون");
    await page.waitForTimeout(800);
    await page.keyboard.type("النيات");
    await page.keyboard.press("Control+Enter");
    await page.waitForTimeout(2500);
    await shot(page, "live-4-reader-search");
    await page.keyboard.press("Escape");
    await page.waitForTimeout(600);
    await tap(page, "فهرست", { exact: true });
    await page.waitForTimeout(900);
    await shot(page, "live-4-reader-toc");
  } catch (e) {
    console.log("live-4 tools skipped:", e.message.split("\n")[0]);
  }
  await ctx.close();
});

await browser.close();

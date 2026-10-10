// Renders the Manabi brand PNGs from the traced SVG logo.
import { chromium } from "playwright";
import { readFileSync } from "node:fs";
// Usage: node icons.mjs <almanabea.svg> <almanabea_mark.svg> <app_icon.svg> <out-dir>
const [, , logoSvg, markSvg, iconSvg, out] = process.argv;
const logo = readFileSync(logoSvg, "utf8").replace("<svg", '<svg style="width:100%;height:auto;display:block"');
const mark = readFileSync(markSvg, "utf8").replace("<svg", '<svg style="width:100%;height:auto;display:block"');
// The launcher icon keeps its own two brand colours (violet + amber lines).
const icon = readFileSync(iconSvg, "utf8").replace("<svg", '<svg style="width:100%;height:auto;display:block"');
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH, args: ["--no-sandbox"] });
const render = async (name, size, { bg = "transparent", art, width, ink = "#000", latin = "#8A8A8A", h = size }) => {
  const page = await browser.newPage({ viewport: { width: size, height: h } });
  await page.setContent(`<html><body style="margin:0;width:${size}px;height:${h}px;background:${bg};display:flex;align-items:center;justify-content:center">
    <div style="width:${width}px">${art}</div>
    <style>svg path{fill:${ink}} svg #latin{fill:${latin}}</style></body></html>`);
  await page.screenshot({ path: `${out}/${name}`, omitBackground: bg === "transparent" });
  await page.close();
};
const renderIcon = async (name, size, { bg = "transparent", width }) => {
  const page = await browser.newPage({ viewport: { width: size, height: size } });
  await page.setContent(`<html><body style="margin:0;width:${size}px;height:${size}px;background:${bg};display:flex;align-items:center;justify-content:center"><div style="width:${width}px">${icon}</div></body></html>`);
  await page.screenshot({ path: `${out}/${name}`, omitBackground: bg === "transparent" });
  await page.close();
};
await renderIcon("icon.png", 1024, { bg: "#FFFFFF", width: 800 });
await renderIcon("icon_foreground.png", 1024, { width: 560 });
await render("splash_android12.png", 960, { art: mark, width: 600, ink: "#6C5CE7" });
await render("splash_logo.png", 1200, { art: logo, width: 1100, ink: "#16161D", latin: "#8A8A96", h: 480 });
await render("splash_logo_dark.png", 1200, { art: logo, width: 1100, ink: "#FFFFFF", latin: "#9D9DAB", h: 480 });
await browser.close();

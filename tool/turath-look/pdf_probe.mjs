// How a Turath PDF is built, and what a range reader must fetch to show one page.
import { PDFDocument, PDFDict, PDFName, PDFArray, PDFRef } from "pdf-lib";
import * as pdfjs from "pdfjs-dist/legacy/build/pdf.mjs";

const url = process.argv[2] || "https://files.turath.io/pdf/shamela/roohm_04.pdf";
const target = Number(process.argv[3] || 284);
const size = Number((await fetch(url, { method: "HEAD" })).headers.get("content-length"));
const head = new Uint8Array(await (await fetch(url, { headers: { range: "bytes=0-2047" } })).arrayBuffer());
console.log("size", size, "linearized", new TextDecoder("latin1").decode(head).includes("/Linearized"));

// pdf.js through a counting range transport.
let requests = 0, bytes = 0;
const transport = new pdfjs.PDFDataRangeTransport(size, null);
transport.requestDataRange = async (begin, end) => {
  requests++; bytes += end - begin;
  const r = await fetch(url, { headers: { range: `bytes=${begin}-${end - 1}` } });
  transport.onDataRange(begin, new Uint8Array(await r.arrayBuffer()));
};
const step = async (label, f) => { const r0 = requests, b0 = bytes, t = Date.now(); await f(); console.log(`pdfjs ${label}: ${requests - r0} requests, ${(bytes - b0) >> 10} KB, ${Date.now() - t} ms`); };
let doc;
await step("open", async () => { doc = await pdfjs.getDocument({ range: transport, length: size, disableAutoFetch: true, disableStream: true, rangeChunkSize: 65536, isEvalSupported: false }).promise; });
console.log("pages", doc.numPages);
await step("page 1", async () => { await (await doc.getPage(1)).getOperatorList(); });
await step(`page ${target}`, async () => { await (await doc.getPage(target)).getOperatorList(); });
await step(`page ${target + 1}`, async () => { await (await doc.getPage(target + 1)).getOperatorList(); });
console.log(`pdfjs total: ${requests} requests, ${bytes >> 10} KB of ${size >> 10} KB`);

// The structure, from the whole file.
const all = new Uint8Array(await (await fetch(url)).arrayBuffer());
const pdf = await PDFDocument.load(all, { updateMetadata: false });
const ctx = pdf.context;
const root = pdf.catalog.lookup(PDFName.of("Pages"), PDFDict);
const kids = root.lookup(PDFName.of("Kids"), PDFArray);
const firstKid = ctx.lookup(kids.get(0));
console.log("root kids", kids.size(), "first kid type", firstKid.lookup(PDFName.of("Type"))?.toString(), "count", root.lookup(PDFName.of("Count"))?.toString());
const objStreams = ctx.enumerateIndirectObjects().filter(([, o]) => o?.dict?.lookup?.(PDFName.of("Type"))?.toString() === "/ObjStm").length;
console.log("object streams", objStreams, "producer", pdf.getProducer(), "creator", pdf.getCreator());
// Where page dicts sit in the file (spread out = one request each).
const text = new TextDecoder("latin1").decode(all);
const pageRefs = pdf.getPages().slice(0, 5).map((p) => p.ref.objectNumber);
console.log("first page objects", pageRefs.map((n) => `${n}@${text.indexOf(`\n${n} 0 obj`)}`).join(" "));

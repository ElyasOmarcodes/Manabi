// The web build's PDF reader: pdf.js (bundled here, Apache-2.0) given the
// file's bytes range by range, by us: the first 64 KB, then only what the
// pages shown need. Left to fetch the URL itself, pdf.js starts with a
// request for the whole file and drops it once it sees ranges are served,
// and what arrived meanwhile is wasted on a slow line.
import * as pdfjs from "./pdf.min.mjs";

pdfjs.GlobalWorkerOptions.workerSrc = new URL("./pdf.worker.min.mjs", import.meta.url).href;

const CHUNK = 65536;
const docs = new Map();
let next = 1;

// Bytes [from, to) of url, tried three times, each within 20 s.
async function range(url, headers, from, to) {
  let error;
  for (let i = 0; i < 3; i++) {
    if (i > 0) await new Promise((r) => setTimeout(r, 700 * i));
    const abort = new AbortController();
    const timer = setTimeout(() => abort.abort(), 20000);
    try {
      const r = await fetch(url, { headers: { ...headers, range: `bytes=${from}-${to - 1}` }, signal: abort.signal });
      if (r.status !== 206 && r.status !== 200) {
        error = new Error(`PDF ${r.status}`);
        if (r.status >= 400 && r.status < 500 && r.status !== 408 && r.status !== 429) break;
        continue;
      }
      return [r, new Uint8Array(await r.arrayBuffer())];
    } catch (e) {
      error = e;
    } finally {
      clearTimeout(timer);
    }
  }
  throw error;
}

// A linearized file says its length in its first bytes (/L), for a server
// on another site whose Content-Range cannot be read.
function linearizedLength(bytes) {
  const head = new TextDecoder("latin1").decode(bytes.subarray(0, 1024));
  const m = /\/Linearized\b[^>]*?\/L\s+(\d+)/.exec(head);
  return m ? Number(m[1]) : 0;
}

window.manabiPdf = {
  /** Opens a document; resolves to [id, pageCount, firstPageWidth, firstPageHeight]. */
  async open(url, headersJson, onProgress) {
    const headers = headersJson ? JSON.parse(headersJson) : {};
    let first = new Uint8Array(0);
    let length = 0;
    try {
      const [res, bytes] = await range(url, headers, 0, CHUNK);
      first = bytes;
      length = res.status === 200 ? bytes.length : Number((res.headers.get("content-range") || "").split("/")[1]) || linearizedLength(bytes);
    } catch (e) {
      // Another site that turns ranges away: pdf.js reads it its own way.
    }
    const options = { disableAutoFetch: true, disableStream: true, rangeChunkSize: CHUNK, isEvalSupported: false };
    let loaded = first.length;
    let failed;
    const failure = new Promise((_, reject) => (failed = reject));
    failure.catch(() => {});
    let task;
    if (length > 0 && first.length >= length) {
      task = pdfjs.getDocument({ ...options, data: first });
    } else if (length > 0) {
      const transport = new pdfjs.PDFDataRangeTransport(length, first);
      transport.requestDataRange = (begin, end) => {
        range(url, headers, begin, end).then(
          ([, bytes]) => {
            loaded += bytes.length;
            onProgress?.(loaded, length);
            transport.onDataRange(begin, bytes);
          },
          (e) => failed(e),
        );
      };
      task = pdfjs.getDocument({ ...options, range: transport });
    } else {
      // Neither told the length: pdf.js reads the file its own way.
      task = pdfjs.getDocument({ ...options, url, httpHeaders: headers });
      if (onProgress) task.onProgress = (p) => onProgress(p.loaded, p.total || 0);
    }
    onProgress?.(loaded, length);
    const doc = await Promise.race([task.promise, failure]);
    const id = next++;
    docs.set(id, { doc, task, failure });
    const firstPage = await Promise.race([doc.getPage(1), failure]);
    const vp = firstPage.getViewport({ scale: 1 });
    return [id, doc.numPages, vp.width, vp.height];
  },

  /** Page size at scale 1: [width, height]. */
  async size(id, n) {
    const page = await docs.get(id).doc.getPage(n);
    const vp = page.getViewport({ scale: 1 });
    return [vp.width, vp.height];
  },

  /** Draws page n at the given pixel width; resolves to an object URL of a JPEG. */
  async render(id, n, width) {
    const d = docs.get(id);
    const draw = async () => {
      const page = await d.doc.getPage(n);
      const base = page.getViewport({ scale: 1 });
      const vp = page.getViewport({ scale: width / base.width });
      const canvas = new OffscreenCanvas(Math.ceil(vp.width), Math.ceil(vp.height));
      const ctx = canvas.getContext("2d");
      ctx.fillStyle = "#fff";
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      await page.render({ canvasContext: ctx, viewport: vp }).promise;
      page.cleanup();
      const blob = await canvas.convertToBlob({ type: "image/jpeg", quality: 0.88 });
      return URL.createObjectURL(blob);
    };
    // A range that never came fails the drawing instead of leaving it waiting.
    return Promise.race([draw(), d.failure]);
  },

  release(url) {
    URL.revokeObjectURL(url);
  },

  close(id) {
    const d = docs.get(id);
    docs.delete(id);
    d?.task.destroy();
  },
};
window.dispatchEvent(new Event("manabi-pdf-ready"));

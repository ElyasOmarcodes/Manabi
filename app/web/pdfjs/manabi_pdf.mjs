// The web build's PDF reader: pdf.js (bundled here, Apache-2.0) asks only
// for the byte ranges of the pages shown, also in files that are not
// linearized, which the PDFium worker downloads whole.
import * as pdfjs from "./pdf.min.mjs";

pdfjs.GlobalWorkerOptions.workerSrc = new URL("./pdf.worker.min.mjs", import.meta.url).href;

const docs = new Map();
let next = 1;

window.manabiPdf = {
  /** Opens a document; resolves to [id, pageCount, firstPageWidth, firstPageHeight]. */
  async open(url, headersJson, onProgress) {
    const task = pdfjs.getDocument({
      url,
      httpHeaders: headersJson ? JSON.parse(headersJson) : undefined,
      disableAutoFetch: true,
      disableStream: true,
      rangeChunkSize: 65536,
      isEvalSupported: false,
    });
    if (onProgress) task.onProgress = (p) => onProgress(p.loaded, p.total || 0);
    const doc = await task.promise;
    const id = next++;
    docs.set(id, { doc, task });
    const first = await doc.getPage(1);
    const vp = first.getViewport({ scale: 1 });
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
    const page = await docs.get(id).doc.getPage(n);
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

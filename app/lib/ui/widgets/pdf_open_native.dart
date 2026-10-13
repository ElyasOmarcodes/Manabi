import 'package:pdfrx/pdfrx.dart';
// The range reader itself is not exported; only its block size is changed here.
// ignore: implementation_imports
import 'package:pdfrx_engine/src/native/pdf_file_cache.dart' show pdfDocumentFromUri;

/// Bytes asked for at a time. The library's default (1 MB) fetches far more
/// than a scanned page needs; a page of a Turath scan is usually 100-300 KB.
const pdfBlockSize = 128 * 1024;

/// Opens a PDF on the network reading only the blocks the shown pages need;
/// blocks once read stay on disk, so a page seen once opens offline.
Future<PdfDocument> openPdfInRanges(Uri uri, {Map<String, String>? headers, PdfDownloadProgressCallback? progress}) async {
  await pdfrxFlutterInitialize();
  return pdfDocumentFromUri(
    uri,
    blockSize: pdfBlockSize,
    useProgressiveLoading: true,
    headers: headers,
    progressCallback: progress,
    timeout: const Duration(seconds: 20),
  );
}

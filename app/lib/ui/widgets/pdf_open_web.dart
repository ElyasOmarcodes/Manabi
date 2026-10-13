import 'package:pdfrx/pdfrx.dart';

/// On the web the PDF worker asks for its own ranges.
Future<PdfDocument> openPdfInRanges(Uri uri, {Map<String, String>? headers, PdfDownloadProgressCallback? progress, void Function()? onFailure}) async {
  await pdfrxFlutterInitialize();
  return PdfDocument.openUri(uri, preferRangeAccess: true, useProgressiveLoading: true, headers: headers, progressCallback: progress);
}

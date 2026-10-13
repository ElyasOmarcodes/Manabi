import 'dart:io';

import 'package:pdfrx/pdfrx.dart';

import '../../core/pdf/range_file.dart';

/// Opens a PDF on the network reading only the blocks the shown pages need;
/// blocks once read stay on disk, so a page seen once opens offline.
/// [onFailure] is told when a part of the file could not be read.
Future<PdfDocument> openPdfInRanges(Uri uri, {Map<String, String>? headers, PdfDownloadProgressCallback? progress, void Function()? onFailure}) async {
  await pdfrxFlutterInitialize();
  progress?.call(0);
  final file = await PdfRangeFile.open(uri, dir: Directory('${Pdfrx.cacheDirectoryPath}/manabi-pdf'), headers: headers);
  file.onProgress = (have, size) => progress?.call(have, size);
  void failed() => onFailure?.call();
  file.failures.addListener(failed);
  void done() {
    file.failures.removeListener(failed);
    file.release();
  }

  try {
    return await PdfDocument.openCustom(read: file.read, fileSize: file.size, sourceName: uri.toString(), useProgressiveLoading: true, onDispose: done);
  } catch (_) {
    done();
    rethrow;
  }
}

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../theme.dart';
import 'common.dart';
import 'pdf_open_web.dart' if (dart.library.io) 'pdf_open_native.dart';

/// Where the viewer reads a Turath PDF from. On the web a browser may not
/// read Turath's range answers from another origin, so the Manabi server
/// relays them (only the ranges asked for); apps read Turath directly.
String pdfViewUrl(String turathUrl, {required bool web, String? serverUrl}) {
  const prefix = 'https://files.turath.io/pdf/';
  final server = serverUrl?.trim().replaceAll(RegExp(r'/+$'), '') ?? '';
  if (!web || server.isEmpty || !turathUrl.startsWith(prefix)) return turathUrl;
  return '$server/api/pdf/${turathUrl.substring(prefix.length)}';
}

/// The printed (scanned) edition of a volume, shown inside the reader.
///
/// [page] is the PDF page the reader wants; the viewer moves there whenever
/// it changes, unless the viewer itself is already on it (so scrolling the
/// PDF, which reports through [onPage], never fights with the reader).
class PdfPane extends StatefulWidget {
  const PdfPane({
    super.key,
    required this.url,
    required this.page,
    required this.onPage,
    required this.offset,
    required this.onOffset,
    required this.onShowText,
    required this.background,
    required this.bar,
    required this.text,
    required this.muted,
    required this.digits,
    this.headers,
  });
  final String url;

  /// Sent with every request (the server's access token, for its relay).
  final Map<String, String>? headers;
  final int page;
  final ValueChanged<int> onPage;

  /// PDF page minus printed page for this book; changed with the align buttons.
  final int offset;
  final ValueChanged<int> onOffset;
  final VoidCallback onShowText;
  final Color background;
  final Color bar;
  final Color text;
  final Color muted;
  final String Function(int) digits;

  @override
  State<PdfPane> createState() => _PdfPaneState();
}

class _PdfPaneState extends State<PdfPane> {
  final _controller = PdfViewerController();
  int? _shown;
  int? _count;

  @override
  void didUpdateWidget(PdfPane old) {
    super.didUpdateWidget(old);
    if (widget.page != _shown && _controller.isReady) {
      final count = _controller.pageCount;
      _controller.goToPage(pageNumber: widget.page.clamp(1, count), duration: Duration.zero);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Stack(children: [
      Positioned.fill(
        // Only the parts of the volume the shown pages need are fetched (HTTP
        // byte ranges), not the whole file; on phones and computers they are
        // kept on disk, so a page seen once opens again without the network.
        child: PdfViewer(
          PdfDocumentRefByLoader(
            (progress) => openPdfInRanges(Uri.parse(widget.url), headers: widget.headers, progress: progress),
            key: PdfDocumentRefKey(widget.url),
          ),
          controller: _controller,
          initialPageNumber: widget.page,
          params: PdfViewerParams(
            backgroundColor: widget.background,
            margin: 10,
            // Mouse wheels and trackpads move about as fast as in the text.
            scrollByMouseWheel: 0.6,
            // Only the pages on screen are measured and read. Measuring every
            // page up front (the default) reads nearly the whole volume.
            behaviorControlParams: const PdfViewerBehaviorControlParams(loadPageDimensionsOnDemand: true),
            onViewerReady: (doc, controller) {
              if (mounted) setState(() => _count = doc.pages.length);
            },
            onPageChanged: (n) {
              if (n == null || n == _shown) return;
              _shown = n;
              widget.onPage(n);
              if (mounted) setState(() {});
            },
            loadingBannerBuilder: (context, downloaded, total) => Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  width: 180,
                  child: AuraProgress(value: total == null || total == 0 ? null : downloaded / total),
                ),
                const SizedBox(height: 10),
                Text(l.pdfLoadingBytes(_size(downloaded)), style: TextStyle(fontFamily: uiFont, fontSize: 12.5, color: widget.muted)),
              ]),
            ),
            errorBannerBuilder: (context, error, stack, ref) => Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.cloud_off_rounded, color: AuraHues.rose, size: 34),
                const SizedBox(height: 10),
                Text(errorText(l, 'NETWORK'), textAlign: TextAlign.center, style: TextStyle(fontFamily: uiFont, color: widget.text)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, children: [
                  SoftButton(icon: Icons.open_in_new_rounded, label: l.pdfOpenOutside, onTap: () => openUrl('${widget.url}#page=${widget.page}')),
                  SoftButton(icon: Icons.notes_rounded, label: l.showText, onTap: widget.onShowText),
                ]),
              ]),
            ),
          ),
        ),
      ),
      // Page, alignment with the text, and the way back to the text.
      Positioned(
        bottom: 12,
        left: 0,
        right: 0,
        child: Center(
          child: Material(
            color: widget.bar.withValues(alpha: 0.94),
            elevation: 3,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                TextButton.icon(
                  onPressed: widget.onShowText,
                  icon: const Icon(Icons.notes_rounded, size: 18),
                  label: Text(l.textView, style: TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w700)),
                ),
                Container(width: 1, height: 22, color: widget.muted.withValues(alpha: 0.3)),
                const SizedBox(width: 10),
                Text(
                  '${l.pdfPage(widget.digits(_shown ?? widget.page))}${_count == null ? '' : ' / ${widget.digits(_count!)}'}',
                  style: TextStyle(fontFamily: uiFont, fontSize: 12.5, color: widget.text, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: '${l.pdfAlign}\n${l.pdfAlignHint}',
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.remove_rounded, size: 18, color: widget.muted),
                      onPressed: () => widget.onOffset(widget.offset - 1),
                    ),
                    if (widget.offset != 0)
                      Text(
                        '${widget.offset > 0 ? '+' : '−'}${widget.digits(widget.offset.abs())}',
                        style: TextStyle(fontFamily: uiFont, fontSize: 11.5, color: widget.muted),
                      ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.add_rounded, size: 18, color: widget.muted),
                      onPressed: () => widget.onOffset(widget.offset + 1),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }

  static String _size(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

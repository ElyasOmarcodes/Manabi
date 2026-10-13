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

  // Opening again (after a part of the file could not be read) starts a new
  // document; the blocks already on disk are reused.
  int _attempt = 0;
  bool _partFailed = false;

  /// Per page: done once its data has been read (a tiny render of it), when
  /// the viewer's own drawing follows at once.
  final _ready = <int, Future<void>>{};
  final _readyDone = <int>{};

  Future<void> _readPage(PdfPage page) async {
    try {
      final img = await page.render(fullWidth: 24, fullHeight: 32, width: 24, height: 32);
      img?.dispose();
      // Later passes over this page show it as it is, with no fade.
      Future<void>.delayed(const Duration(seconds: 1), () => _readyDone.add(page.pageNumber));
    } catch (_) {}
  }

  void _onFailure() {
    if (_partFailed || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _partFailed = true);
    });
  }

  void _again() => setState(() {
    _attempt++;
    _partFailed = false;
    _count = null;
  });

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
    return Stack(
      children: [
        Positioned.fill(
          // Only the parts of the volume the shown pages need are fetched (HTTP
          // byte ranges), not the whole file; on phones and computers they are
          // kept on disk, so a page seen once opens again without the network.
          child: PdfViewer(
            PdfDocumentRefByLoader(
              (progress) => openPdfInRanges(Uri.parse(widget.url), headers: widget.headers, progress: progress, onFailure: _onFailure),
              key: PdfDocumentRefKey(widget.url, [_attempt]),
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
              // Scans have no text to select; looking for it parses each page's
              // content on the worker the drawing waits for.
              textSelectionParams: const PdfTextSelectionParams(enabled: false),
              // Over each page until its data is read: the outline of a page of
              // text, breathing, so a page still coming never looks empty.
              pageOverlaysBuilder: (context, rect, page) => [
                if (!_readyDone.contains(page.pageNumber))
                  _PageLoading(
                    key: ValueKey('$_attempt:${page.pageNumber}'),
                    ready: _ready.putIfAbsent(page.pageNumber, () => _readPage(page)),
                    number: widget.digits(page.pageNumber),
                    color: widget.muted,
                  ),
              ],
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 180, child: AuraProgress(value: total == null || total == 0 ? null : downloaded / total)),
                    const SizedBox(height: 10),
                    Text(
                      l.pdfLoadingBytes(_size(downloaded)),
                      style: TextStyle(fontFamily: uiFont, fontSize: 12.5, color: widget.muted),
                    ),
                  ],
                ),
              ),
              errorBannerBuilder: (context, error, stack, ref) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_rounded, color: AuraHues.rose, size: 34),
                    const SizedBox(height: 10),
                    Text(
                      errorText(l, 'NETWORK'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: uiFont, color: widget.text),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        SoftButton(icon: Icons.refresh_rounded, label: l.retry, onTap: _again),
                        SoftButton(icon: Icons.open_in_new_rounded, label: l.pdfOpenOutside, onTap: () => openUrl('${widget.url}#page=${widget.page}')),
                        SoftButton(icon: Icons.notes_rounded, label: l.showText, onTap: widget.onShowText),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_partFailed)
          Positioned(
            top: 10,
            left: 12,
            right: 12,
            child: Center(
              child: Material(
                color: widget.bar.withValues(alpha: 0.96),
                elevation: 3,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 4, 4, 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off_rounded, size: 18, color: AuraHues.rose),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          l.pdfPartFailed,
                          style: TextStyle(fontFamily: uiFont, fontSize: 12.5, color: widget.text),
                        ),
                      ),
                      TextButton(
                        onPressed: _again,
                        child: Text(
                          l.retry,
                          style: TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: widget.onShowText,
                      icon: const Icon(Icons.notes_rounded, size: 18),
                      label: Text(
                        l.textView,
                        style: TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w700),
                      ),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _size(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

class _PageLoading extends StatefulWidget {
  const _PageLoading({super.key, required this.ready, required this.number, required this.color});
  final Future<void> ready;
  final String number;
  final Color color;
  @override
  State<_PageLoading> createState() => _PageLoadingState();
}

class _PageLoadingState extends State<_PageLoading> with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat(reverse: true);
  bool _done = false;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    widget.ready.whenComplete(() {
      if (!mounted) return;
      _breath.stop();
      // A moment for the viewer to draw the page under the fading outline.
      Future<void>.delayed(const Duration(milliseconds: 150), () {
        if (mounted) setState(() => _done = true);
      });
    });
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_gone) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _done ? 0 : 1,
        duration: const Duration(milliseconds: 280),
        onEnd: () {
          if (_done && mounted) setState(() => _gone = true);
        },
        child: ColoredBox(
          color: Colors.white,
          child: AnimatedBuilder(
            animation: _breath,
            builder: (context, _) => CustomPaint(painter: _SkeletonPainter(widget.color, 0.08 + 0.08 * _breath.value, widget.number)),
          ),
        ),
      ),
    );
  }
}

class _SkeletonPainter extends CustomPainter {
  _SkeletonPainter(this.color, this.alpha, this.number);
  final Color color;
  final double alpha;
  final String number;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final line = Paint()..color = color.withValues(alpha: alpha);
    final gap = h * 0.045;
    final thick = (h * 0.012).clamp(3.0, 14.0);
    for (var i = 0; i < 17; i++) {
      final y = h * 0.1 + i * gap;
      if (y > h * 0.86) break;
      // Lines of a right-to-left page: flush right, a paragraph's last one shorter.
      final len = w * (i % 5 == 4 ? 0.42 : 0.8);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.9 - len, y, len, thick), Radius.circular(thick / 2)), line);
    }
    final tp = TextPainter(
      text: TextSpan(
        text: number,
        style: TextStyle(fontFamily: uiFont, fontSize: (w * 0.06).clamp(12.0, 36.0), fontWeight: FontWeight.w700, color: color.withValues(alpha: 0.45)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(w / 2 - tp.width / 2, h * 0.93 - tp.height / 2));
  }

  @override
  bool shouldRepaint(_SkeletonPainter old) => old.alpha != alpha || old.color != color || old.number != number;
}

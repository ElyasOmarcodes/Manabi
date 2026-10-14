// The web build's PDF view, on pdf.js (web/pdfjs). PDFium's web worker
// downloads a whole volume before it can draw a page far into it; pdf.js
// asks only for the byte ranges of the pages shown (about 200 KB a page).
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';

import 'pdf_skeleton.dart';

extension type _Pdf._(JSObject _) implements JSObject {
  external JSPromise<JSArray<JSNumber>> open(JSString url, JSString? headers, JSFunction? onProgress);
  external JSPromise<JSString> render(JSNumber id, JSNumber page, JSNumber width);
  external void release(JSString url);
  external void close(JSNumber id);
}

Future<_Pdf>? _loading;

/// Loads web/pdfjs/manabi_pdf.mjs once, on the first PDF opened.
Future<_Pdf> _pdfjs() => _loading ??= () async {
  final existing = globalContext['manabiPdf'];
  if (existing != null) return existing as _Pdf;
  final ready = Completer<void>();
  final onReady = (JSAny _) {
    if (!ready.isCompleted) ready.complete();
  }.toJS;
  globalContext.callMethod('addEventListener'.toJS, 'manabi-pdf-ready'.toJS, onReady);
  final document = globalContext['document'] as JSObject;
  final script = document.callMethod<JSObject>('createElement'.toJS, 'script'.toJS);
  script['type'] = 'module'.toJS;
  script['src'] = 'pdfjs/manabi_pdf.mjs'.toJS;
  script['onerror'] = ((JSAny _) {
    if (!ready.isCompleted) ready.completeError(StateError('pdf.js did not load'));
  }).toJS;
  (document['head'] as JSObject).callMethod('appendChild'.toJS, script);
  await ready.future;
  return globalContext['manabiPdf'] as _Pdf;
}();

/// One volume's pages in a column. The loading banner stays until the page
/// asked for is drawn, so it gives way to that page, never to a blank one;
/// pages further off show their outline until drawn.
class WebPdfPages extends StatefulWidget {
  const WebPdfPages({
    super.key,
    required this.url,
    required this.page,
    required this.onPage,
    required this.onCount,
    required this.background,
    required this.muted,
    required this.digits,
    required this.loading,
    required this.error,
    this.headers,
    this.fallbackUrl,
  });
  final String url;
  final String? fallbackUrl;
  final Map<String, String>? headers;
  final int page;
  final ValueChanged<int> onPage;
  final ValueChanged<int> onCount;
  final Color background;
  final Color muted;
  final String Function(int) digits;
  final Widget Function(int bytes) loading;
  final Widget Function(VoidCallback retry) error;

  @override
  State<WebPdfPages> createState() => _WebPdfPagesState();
}

class _WebPdfPagesState extends State<WebPdfPages> {
  _Pdf? _pdf;
  int? _id;
  int _count = 0;
  double _aspect = 1.414;
  int _bytes = 0;
  Object? _error;
  bool _ready = false;
  bool _waiting = false;
  int _shown = 1;
  ScrollController? _scroll;
  double _extent = 0;
  int _width = 0;

  /// Drawn pages as object URLs, the most recent last (a few are kept).
  final _images = <int, Future<String?>>{};
  final _order = <int>[];

  @override
  void initState() {
    super.initState();
    _shown = widget.page;
    _open();
  }

  Future<void> _open() async {
    setState(() {
      _error = null;
      _ready = false;
      _waiting = false;
      _bytes = 0;
    });
    try {
      final pdf = _pdf = await _pdfjs();
      final progress = ((JSNumber loaded, JSNumber total) {
        if (mounted) setState(() => _bytes = loaded.toDartInt);
      }).toJS;
      final headers = widget.headers == null || widget.headers!.isEmpty ? null : jsonEncode(widget.headers).toJS;
      JSArray<JSNumber> opened;
      try {
        opened = await pdf.open(widget.url.toJS, headers, progress).toDart;
      } catch (_) {
        // The relay is missing (another host): Turath itself, slower.
        if (widget.fallbackUrl == null) rethrow;
        opened = await pdf.open(widget.fallbackUrl!.toJS, null, progress).toDart;
      }
      final r = opened.toDart;
      if (!mounted) {
        pdf.close(r[0]);
        return;
      }
      _id = r[0].toDartInt;
      _count = r[1].toDartInt;
      _aspect = r[3].toDartDouble / r[2].toDartDouble;
      widget.onCount(_count);
      setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _reopen() {
    _dispose();
    _open();
  }

  @override
  void didUpdateWidget(WebPdfPages old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _dispose();
      _open();
      return;
    }
    if (widget.page != _shown && _scroll != null && _scroll!.hasClients && _extent > 0) {
      _shown = widget.page;
      _scroll!.jumpTo((widget.page - 1).clamp(0, _count - 1) * _extent);
    }
  }

  Future<String?> _image(int n) {
    final kept = _images[n];
    if (kept != null) {
      _order
        ..remove(n)
        ..add(n);
      return kept;
    }
    final f = _render(n);
    _images[n] = f;
    _order.add(n);
    while (_order.length > 14) {
      final old = _order.removeAt(0);
      _images.remove(old)?.then((u) => u == null ? null : _pdf?.release(u.toJS));
    }
    return f;
  }

  Future<String?> _render(int n) async {
    final pdf = _pdf;
    final id = _id;
    if (pdf == null || id == null) return null;
    try {
      return (await pdf.render(id.toJS, n.toJS, _width.toJS).toDart).toDart;
    } catch (e) {
      // A range that did not come: pdf.js waits on it for good, so the
      // volume is opened again from the banner's button.
      _images.remove(n);
      _order.remove(n);
      if (mounted && id == _id) setState(() => _error = e);
      return null;
    }
  }

  void _onScroll() {
    if (_extent <= 0) return;
    final c = _scroll!;
    final n = ((c.offset + c.position.viewportDimension / 3) / _extent).floor() + 1;
    final page = n.clamp(1, _count);
    if (page != _shown) {
      _shown = page;
      widget.onPage(page);
    }
  }

  void _dispose() {
    for (final f in _images.values) {
      f.then((u) => u == null ? null : _pdf?.release(u.toJS));
    }
    _images.clear();
    _order.clear();
    if (_id != null) _pdf?.close(_id!.toJS);
    _id = null;
    _scroll?.dispose();
    _scroll = null;
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return widget.error(_reopen);
    if (_id == null) return widget.loading(_bytes);
    return LayoutBuilder(
      builder: (context, c) {
        const margin = 10.0;
        final pageWidth = (c.maxWidth - margin * 2).clamp(100.0, 1100.0);
        final pageHeight = pageWidth * _aspect;
        _extent = pageHeight + margin;
        // Drawn a little sharper than the screen, at most 1800 pixels wide.
        _width = (pageWidth * MediaQuery.devicePixelRatioOf(context) * 1.1).clamp(300, 1800).round();
        if (!_ready) {
          // The page asked for first; the viewer shows when it is drawn.
          final target = widget.page.clamp(1, _count);
          if (!_waiting) {
            _waiting = true;
            _image(target).then((_) {
              if (!mounted || _ready || _error != null) return;
              _scroll = ScrollController(initialScrollOffset: (target - 1) * _extent)..addListener(_onScroll);
              setState(() => _ready = true);
              if (target < _count) _image(target + 1);
            });
          }
          return widget.loading(_bytes);
        }
        return InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          panEnabled: false,
          child: ColoredBox(
            color: widget.background,
            child: ListView.builder(
              controller: _scroll,
              itemCount: _count,
              itemExtent: _extent,
              padding: const EdgeInsets.symmetric(horizontal: margin),
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: margin),
                child: _WebPage(key: ValueKey(i), image: _image(i + 1), number: widget.digits(i + 1), muted: widget.muted),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WebPage extends StatelessWidget {
  const _WebPage({super.key, required this.image, required this.number, required this.muted});
  final Future<String?> image;
  final String number;
  final Color muted;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Colors.white,
      boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 4, offset: Offset(0, 2))],
    ),
    child: FutureBuilder<String?>(
      future: image,
      builder: (context, snap) {
        final url = snap.data;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: url == null
              ? PdfPageSkeleton(key: const ValueKey(0), number: number, color: muted)
              : Image.network(url, key: ValueKey(url), fit: BoxFit.fill, gaplessPlayback: true, width: double.infinity, height: double.infinity),
        );
      },
    ),
  );
}

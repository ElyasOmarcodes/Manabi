import 'package:flutter/material.dart';

/// Apps draw PDFs with PDFium (pdf_pane.dart); this is never built there.
class WebPdfPages extends StatelessWidget {
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
  Widget build(BuildContext context) => throw UnsupportedError('pdf.js is for the web build');
}

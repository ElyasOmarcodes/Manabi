import 'package:flutter/material.dart';

import '../../state/catalog_sync.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/brand_logo.dart';

/// First launch: builds the library on the device, step by step, then
/// opens the app.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.sync, required this.onDone});
  final CatalogSync sync;
  final VoidCallback onDone;
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  @override
  void initState() {
    super.initState();
    widget.sync.addListener(_changed);
    widget.sync.run(firstRun: true).then((_) {
      final failed = widget.sync.states.values.contains(SyncState.failed);
      // Straight on when all went well; otherwise the note and a button.
      if (!failed && mounted) Future<void>.delayed(const Duration(milliseconds: 700), () => mounted ? widget.onDone() : null);
    });
  }

  @override
  void dispose() {
    widget.sync.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    final s = widget.sync;
    final failed = !s.running && s.states.values.contains(SyncState.failed);
    final steps = [
      (SyncStep.storage, Icons.folder_open_rounded, l.setupStorage),
      (SyncStep.catalog, Icons.local_library_outlined, l.setupCatalog),
      (SyncStep.extraBooks, Icons.library_add_outlined, l.setupExtra),
      (SyncStep.pdfFlags, Icons.picture_as_pdf_outlined, l.setupPdf),
    ];
    return Scaffold(
      backgroundColor: a.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Center(child: BrandLogo(height: 64)),
                const SizedBox(height: 26),
                Text(l.setupTitle, textAlign: TextAlign.center, style: TextStyle(fontFamily: uiFont, fontSize: 21, fontWeight: FontWeight.w800, color: a.text)),
                const SizedBox(height: 8),
                Text(l.setupSub, textAlign: TextAlign.center, style: TextStyle(fontFamily: uiFont, fontSize: 13.5, height: 1.7, color: a.muted)),
                const SizedBox(height: 22),
                Center(child: AuraProgress(value: s.progress, width: 260, height: 6)),
                const SizedBox(height: 20),
                for (final (step, icon, label) in steps) _StepRow(icon: icon, label: label, state: s.states[step]!, detail: s.details[step]),
                if (failed) ...[
                  const SizedBox(height: 12),
                  Text(l.setupOfflineNote, textAlign: TextAlign.center, style: TextStyle(fontFamily: uiFont, fontSize: 12.5, height: 1.6, color: a.muted)),
                  const SizedBox(height: 14),
                  FilledButton(onPressed: widget.onDone, child: Text(l.setupContinue)),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.icon, required this.label, required this.state, this.detail});
  final IconData icon;
  final String label;
  final SyncState state;
  final String? detail;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    final (color, trailing) = switch (state) {
      SyncState.done => (AuraHues.green, const Icon(Icons.check_circle_rounded, color: AuraHues.green, size: 20) as Widget),
      SyncState.failed => (AuraHues.amber, const Icon(Icons.cloud_off_rounded, color: AuraHues.amber, size: 20) as Widget),
      SyncState.running => (a.accent, const AuraProgress(width: 36, height: 4) as Widget),
      SyncState.waiting => (a.faint, Icon(Icons.circle_outlined, color: a.faint, size: 18) as Widget),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: state == SyncState.running ? a.accentTint : a.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: a.border),
      ),
      child: Row(children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontFamily: uiFont, fontSize: 14, fontWeight: FontWeight.w600, color: a.text)),
            if (detail != null)
              Text(detail!, maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.ltr, style: TextStyle(fontFamily: uiFont, fontSize: 11.5, color: a.muted)),
          ]),
        ),
        trailing,
      ]),
    );
  }
}

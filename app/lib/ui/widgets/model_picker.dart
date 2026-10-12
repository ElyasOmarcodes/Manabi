import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/backend/backend.dart';
import '../../core/gemini/gemini_client.dart' show ModelInfo, modelCost;
import '../../state/settings_controller.dart';
import '../theme.dart';
import 'common.dart';

/// One listing per backend, so reopening the picker is instant.
final _listings = Expando<Future<({List<ModelInfo> models, String? auto})>>();

Future<({List<ModelInfo> models, String? auto})> _listing(ManabiBackend backend, {bool fresh = false}) {
  final kept = _listings[backend];
  if (kept != null && !fresh) return kept;
  final f = backend.models();
  _listings[backend] = f;
  // A failed listing is tried again next time.
  f.catchError((Object _) {
    _listings[backend] = null;
    return (models: const <ModelInfo>[], auto: null);
  });
  return f;
}

/// A short name for a model id: "gemini-2.5-flash" → "Gemini 2.5 Flash".
String modelShortName(String id) => id
    .split('-')
    .map((p) => p.isEmpty ? p : (RegExp(r'^\d').hasMatch(p) ? p : '${p[0].toUpperCase()}${p.substring(1)}'))
    .join(' ');

Color costColor(String cost) => switch (cost) {
      'low' => AuraHues.teal,
      'high' => AuraHues.rose,
      _ => AuraHues.amber,
    };

/// Three rising bars: one for a cheap model, three for an expensive one.
class CostMeter extends StatelessWidget {
  const CostMeter({super.key, required this.cost, this.label = true});
  final String cost;
  final bool label;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    final n = switch (cost) { 'low' => 1, 'high' => 3, _ => 2 };
    final color = costColor(cost);
    final text = switch (cost) { 'low' => l.costLow, 'high' => l.costHigh, _ => l.costMedium };
    return Tooltip(
      message: text,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: label ? 8 : 5, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: a.dark ? 0.18 : 0.1), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 3.5,
              height: 6.0 + i * 3,
              margin: const EdgeInsetsDirectional.only(end: 2),
              decoration: BoxDecoration(color: i < n ? color : color.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(2)),
            ),
          if (label) ...[
            const SizedBox(width: 4),
            Text(text, style: TextStyle(fontFamily: uiFont, fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ],
        ]),
      ),
    );
  }
}

String _tokens(int n) => n >= 1000000 ? '${(n / 1000000).toStringAsFixed(n % 1000000 == 0 ? 0 : 1)}M' : (n >= 1000 ? '${(n / 1000).round()}K' : '$n');

/// Every text model the key can call, with its cost, and "automatic" on top.
Future<void> showModelPicker(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ModelSheet(),
    );

class _ModelSheet extends StatefulWidget {
  const _ModelSheet();
  @override
  State<_ModelSheet> createState() => _ModelSheetState();
}

class _ModelSheetState extends State<_ModelSheet> {
  late final SettingsController _s = context.read<SettingsController>();
  late Future<({List<ModelInfo> models, String? auto})> _future = _listing(_s.backend);

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    final l = context.l;
    final a = context.aura;
    Widget row({required String title, String? sub, required bool selected, required VoidCallback onTap, Widget? trailing, IconData icon = Icons.memory_rounded, Color? color}) => Pressable(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? a.accentTint : a.surfaceAlt,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? a.accent : Colors.transparent, width: 1.3),
            ),
            child: Row(children: [
              Icon(icon, size: 20, color: color ?? a.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(fontFamily: uiFont, fontSize: 14, fontWeight: FontWeight.w700, color: a.text)),
                  if (sub != null) Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 11.5, color: a.muted)),
                ]),
              ),
              ?trailing,
              const SizedBox(width: 6),
              Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined, size: 20, color: selected ? a.accent : a.faint),
            ]),
          ),
        );
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.82),
        child: FutureBuilder(
          future: _future,
          builder: (context, snap) {
            final data = snap.data;
            final models = data?.models ?? const <ModelInfo>[];
            final gemini = [for (final m in models) if (!m.id.startsWith('gemma')) m];
            final gemma = [for (final m in models) if (m.id.startsWith('gemma')) m];
            // A saved pick the key no longer lists still shows, so it can be cleared.
            final unknown = s.chatModel.isNotEmpty && data != null && !models.any((m) => m.id == s.chatModel);
            Widget model(ModelInfo m) => row(
                  title: m.name,
                  sub: [m.id, if (m.input > 0) '${_tokens(m.input)} ↹'].join('  ·  '),
                  selected: s.chatModel == m.id,
                  color: costColor(m.cost),
                  icon: m.id.startsWith('gemma') ? Icons.diamond_outlined : Icons.auto_awesome_rounded,
                  trailing: CostMeter(cost: m.cost),
                  onTap: () => s.setChatModel(m.id),
                );
            Widget header(String t) => Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(6, 10, 6, 6),
                  child: Text(t, style: TextStyle(fontFamily: uiFont, fontSize: 12.5, fontWeight: FontWeight.w700, color: a.muted)),
                );
            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Text(l.answerModel, style: TextStyle(fontFamily: uiFont, fontSize: 17, fontWeight: FontWeight.w800, color: a.text)),
                const SizedBox(height: 4),
                Text(l.modelPickerNote, style: TextStyle(fontFamily: uiFont, fontSize: 12, height: 1.6, color: a.muted)),
                const SizedBox(height: 12),
                row(
                  title: l.modelAuto,
                  sub: data?.auto != null ? l.modelAutoSub(modelShortName(data!.auto!)) : l.modelAutoInfo,
                  selected: s.chatModel.isEmpty,
                  icon: Icons.auto_mode_rounded,
                  color: a.accent,
                  trailing: data?.auto != null ? CostMeter(cost: modelCost(data!.auto!), label: false) : null,
                  onTap: () => s.setChatModel(''),
                ),
                if (unknown) row(title: modelShortName(s.chatModel), sub: s.chatModel, selected: true, onTap: () => s.setChatModel('')),
                if (snap.connectionState != ConnectionState.done)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 22), child: Center(child: AuraProgress()))
                else if (snap.hasError || models.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(children: [
                      Text(snap.hasError ? errorText(l, mapError(snap.error!).code) : l.modelsLoadFailed,
                          textAlign: TextAlign.center, style: TextStyle(fontFamily: uiFont, fontSize: 13, color: a.muted)),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => setState(() => _future = _listing(_s.backend, fresh: true)),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(l.retry),
                      ),
                    ]),
                  )
                else ...[
                  header('${s.mode == ConnectionMode.direct ? l.modelsFromKey : l.modelsFromServer} · ${models.length}'),
                  if (gemini.isNotEmpty) ...[header('Gemini'), for (final m in gemini) model(m)],
                  if (gemma.isNotEmpty) ...[header('Gemma'), for (final m in gemma) model(m)],
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

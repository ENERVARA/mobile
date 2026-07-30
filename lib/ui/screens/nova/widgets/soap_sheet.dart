import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../../core/ui/app_messenger.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/chat.dart';
import '../../../../state/chat_provider.dart';

/// "Show this to your doctor" — the SOAP note export.
///
/// Regenerated on every open (and on Regenerate) from the latest conversation,
/// so it always reflects the full thread as it stands.
Future<void> showSoapSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _SoapSheet(),
  );
}

class _SoapSheet extends ConsumerStatefulWidget {
  const _SoapSheet();

  @override
  ConsumerState<_SoapSheet> createState() => _SoapSheetState();
}

class _SoapSheetState extends ConsumerState<_SoapSheet> {
  SoapNote? _note;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final note = await ref.read(chatProvider.notifier).generateSoapNote();
    if (!mounted) return;
    setState(() {
      _note = note;
      _failed = note == null;
      _loading = false;
    });
  }

  void _copy() {
    final note = _note;
    if (note == null) return;
    Clipboard.setData(ClipboardData(text: note.toPlainText()));
    AppMessenger.success('Summary copied');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: t.line, borderRadius: BorderRadius.circular(999)),
          ),
          const SizedBox(height: 16),
          _header(context),
          Divider(height: 1, thickness: 1, color: t.line),
          Flexible(child: _body(context)),
          if (_note != null) _actions(context),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 8, 14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(PhosphorIconsBold.stethoscope, size: 17, color: AppColors.tealD),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'For your doctor',
                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: t.ink),
                ),
                Text(
                  _subtitle(),
                  style: TextStyle(fontSize: 11.5, color: t.ink3),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close, size: 20, color: t.ink3),
          ),
        ],
      ),
    );
  }

  String _subtitle() {
    final at = _note?.generatedAt;
    if (at == null) return 'Summary of this conversation';
    final dt = Formatters.tryParse(at);
    if (dt == null) return 'Summary of this conversation';
    return 'Generated ${Formatters.timeAgo(dt)}';
  }

  Widget _body(BuildContext context) {
    final t = context.tokens;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 56),
        child: Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.teal),
          ),
        ),
      );
    }

    if (_failed || _note == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIconsRegular.warningCircle, size: 30, color: t.ink3),
            const SizedBox(height: 12),
            Text(
              "Couldn't build the summary",
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: t.ink),
            ),
            const SizedBox(height: 5),
            Text(
              'Try again in a moment.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.4, color: t.ink3),
            ),
            const SizedBox(height: 16),
            _pillButton(
              label: 'Retry',
              icon: PhosphorIconsRegular.arrowClockwise,
              filled: true,
              onTap: _load,
            ),
          ],
        ),
      );
    }

    final note = _note!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _section(context, 'S', 'Subjective', note.subjective),
          _section(context, 'O', 'Objective', note.objective),
          _section(context, 'A', 'Assessment', note.assessment),
          _section(context, 'P', 'Plan', note.plan),
          if (note.unavailable.isNotEmpty) _unavailable(context, note.unavailable),
          const SizedBox(height: 6),
          Text(
            'Generated from this conversation only. Not a diagnosis.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.9,
              height: 1.35,
              fontStyle: FontStyle.italic,
              color: t.ink3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String letter, String label, String body) {
    final t = context.tokens;
    final text = body.trim().isEmpty ? 'Not documented.' : body.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
                child: Text(
                  letter,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: t.ink2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: t.soft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.line),
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: body.trim().isEmpty ? t.ink3 : t.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _unavailable(BuildContext context, List<String> items) {
    final t = context.tokens;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'NOT DOCUMENTED IN THIS CONVERSATION',
            style: TextStyle(
              fontSize: 10.8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: t.ink2,
            ),
          ),
          const SizedBox(height: 7),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(color: AppColors.amber, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    items[i],
                    style: TextStyle(fontSize: 12.9, height: 1.35, color: t.ink2),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _actions(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: t.line))),
      child: Row(
        children: [
          Expanded(
            child: _pillButton(
              label: 'Regenerate',
              icon: PhosphorIconsRegular.arrowClockwise,
              filled: false,
              onTap: _loading ? null : _load,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _pillButton(
              label: 'Copy',
              icon: PhosphorIconsRegular.copy,
              filled: true,
              onTap: _loading ? null : _copy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pillButton({
    required String label,
    required IconData icon,
    required bool filled,
    required VoidCallback? onTap,
  }) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: filled ? AppColors.teal : t.soft,
            borderRadius: BorderRadius.circular(12),
            border: filled ? null : Border.all(color: t.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: filled ? Colors.white : t.ink2),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.4,
                  fontWeight: FontWeight.w600,
                  color: filled ? Colors.white : t.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

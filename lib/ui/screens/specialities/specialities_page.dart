import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/context_ext.dart';
import '../../../data/constants/specialities.dart';
import '../../widgets/page_header.dart';
import '../../widgets/speciality_card.dart';

/// Specialities — ported from `SpecialitiesPage.tsx`. Same image cards as the
/// dashboard, filtered by a live search over name + short description.
class SpecialitiesPage extends StatefulWidget {
  const SpecialitiesPage({super.key});

  @override
  State<SpecialitiesPage> createState() => _SpecialitiesPageState();
}

class _SpecialitiesPageState extends State<SpecialitiesPage> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final q = _query.toLowerCase();
    final filtered = kSpecialities
        .where((s) =>
            s.name.toLowerCase().contains(q) ||
            s.shortDescription.toLowerCase().contains(q))
        .toList();

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
        children: [
          const PageHeader(
            title: 'Specialities',
            subtitle: 'Browse our medical specialities and connect with the right specialist.',
          ),
          // Search
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.line, width: 1.5),
            ),
            child: Row(
              children: [
                Icon(PhosphorIconsRegular.magnifyingGlass, size: 17, color: t.ink3),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onChanged: (v) => setState(() => _query = v),
                    style: TextStyle(fontSize: 14, color: t.ink),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Search specialities…',
                      hintStyle: TextStyle(fontSize: 14, color: t.ink3),
                    ),
                  ),
                ),
                if (_query.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _controller.clear();
                      setState(() => _query = '');
                    },
                    child: Icon(PhosphorIconsRegular.x, size: 15, color: t.ink3),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 64),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: t.line),
              ),
              child: Center(
                child: Text(
                  'No specialities found for “$_query”.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14.4, color: t.ink2),
                ),
              ),
            )
          else
            for (final s in filtered) ...[
              SpecialityCard(speciality: s),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

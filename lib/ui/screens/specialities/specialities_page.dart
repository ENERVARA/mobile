import 'package:flutter/material.dart';

import '../../../core/theme/context_ext.dart';
import '../../../data/constants/specialities.dart';
import '../../widgets/common.dart';
import '../../widgets/page_header.dart';
import '../../widgets/speciality_card.dart';

/// Specialities — ported from `SpecialitiesPage.tsx`. Same image cards as the
/// dashboard, filtered by a live search over name + short description; one column
/// at mobile width.
class SpecialitiesPage extends StatefulWidget {
  const SpecialitiesPage({super.key});

  @override
  State<SpecialitiesPage> createState() => _SpecialitiesPageState();
}

class _SpecialitiesPageState extends State<SpecialitiesPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final q = _query.toLowerCase();
    final filtered = kSpecialities
        .where((s) =>
            s.name.toLowerCase().contains(q) || s.shortDescription.toLowerCase().contains(q))
        .toList();

    return ShellPage(
      children: [
        PageHeader(
          title: 'Specialities',
          subtitle: 'Browse our medical specialities and connect with the right specialist.',
          // `w-full min-w-[240px] max-w-[320px]`
          action: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320, minWidth: 240),
            child: SearchField(
              hint: 'Search specialities…',
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ),
        if (filtered.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 64),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: t.line),
            ),
            child: Text(
              'No specialities found for “$_query”.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.4, height: 1.5, color: t.ink2),
            ),
          )
        else
          for (var i = 0; i < filtered.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            SpecialityCard(speciality: filtered[i]),
          ],
      ],
    );
  }
}

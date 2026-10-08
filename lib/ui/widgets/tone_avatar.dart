import 'package:flutter/material.dart';

/// The six brand tones for initials avatars. Ported from `ToneAvatar.tsx`.
enum Tone { t1, t2, t3, t4, t5, t6 }

const Map<Tone, Color> _toneBg = {
  Tone.t1: Color(0xFF0BB5A6),
  Tone.t2: Color(0xFF2CB0C8),
  Tone.t3: Color(0xFF8168C4),
  Tone.t4: Color(0xFFF26440),
  Tone.t5: Color(0xFFE0A51F),
  Tone.t6: Color(0xFF16A085),
};

/// Circular initials avatar in one of the six brand tones (redesign).
class ToneAvatar extends StatelessWidget {
  final String initials;
  final Tone tone;
  final double size;
  final double? fontSize;

  const ToneAvatar({
    super.key,
    required this.initials,
    required this.tone,
    this.size = 46,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: _toneBg[tone], shape: BoxShape.circle),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: fontSize ?? size * 0.34,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Ported from `src/utils/provider.ts`.
class ProviderNames {
  ProviderNames._();

  static final _title = RegExp(r'^(dr\.?|prof\.?|mr\.?|ms\.?|mrs\.?)\s+', caseSensitive: false);

  /// A clinician's registered name usually carries the title already ("Dr Aravind
  /// Mehta"), so initials taken from the raw string come out as "DA". Drop the
  /// title first and the avatar reads as the person.
  static String initials(String fullName) {
    final parts =
        fullName.replaceFirst(_title, '').split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  /// Stable per-doctor colour: the same clinician keeps the same tone.
  static Tone tone(String id) {
    var hash = 0;
    for (final unit in id.codeUnits) {
      hash = (hash * 31 + unit) & 0xFFFFFFFF;
    }
    return Tone.values[hash % Tone.values.length];
  }

  /// Always shows the title, whether or not the registered name carries one.
  static String titled(String fullName) =>
      RegExp(r'^(dr\.?|prof\.?)\s+', caseSensitive: false).hasMatch(fullName)
          ? fullName
          : 'Dr $fullName';
}

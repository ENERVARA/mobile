import '../constants/specialities.dart';

/// A speciality suggestion returned by triage.
class SuggestedSpeciality {
  final String slug;
  final String name;
  final String reason;
  const SuggestedSpeciality({required this.slug, required this.name, required this.reason});
}

class MedicalQueryResult {
  final String answer;
  final SuggestedSpeciality? suggestedSpeciality;
  const MedicalQueryResult({required this.answer, this.suggestedSpeciality});
}

class _Rule {
  final String slug;
  final String reason;
  final List<String> keywords;
  const _Rule(this.slug, this.reason, this.keywords);
}

/// Medical-query triage — ports the keyword heuristic in
/// `src/services/medicalQueryService.ts`. Swap the body of [askMedicalQuery]
/// with a real endpoint when the backend triage route ships.
class MedicalQueryService {
  const MedicalQueryService();

  static const _rules = <_Rule>[
    _Rule('cardiology', 'Your symptoms relate to the heart and circulation.', [
      'chest', 'heart', 'palpitation', 'palpitations', 'blood pressure', 'bp', 'breathless', 'pulse',
    ]),
    _Rule('gastroenterology', 'This sounds like a digestive concern.', [
      'stomach', 'acid', 'reflux', 'nausea', 'vomit', 'bloating', 'digestion', 'bowel', 'gut',
      'heartburn', 'diarrhea', 'constipation',
    ]),
    _Rule('dermatology', 'Skin concerns are best handled by dermatology.', [
      'skin', 'rash', 'acne', 'itch', 'itchy', 'eczema', 'pimple', 'mole', 'hives',
    ]),
    _Rule('ent', 'Ear, nose and throat symptoms map to ENT.', [
      'ear', 'nose', 'throat', 'sinus', 'hearing', 'tonsil', 'sore throat', 'congestion', 'vertigo',
    ]),
  ];

  Future<MedicalQueryResult> askMedicalQuery(String query) async {
    await Future.delayed(const Duration(milliseconds: 700));
    final q = query.toLowerCase();

    for (final rule in _rules) {
      if (isSpecialityEnabled(rule.slug) && rule.keywords.any(q.contains)) {
        return MedicalQueryResult(
          answer:
              "Thanks for sharing that. It's best reviewed by a specialist rather than general advice — "
              "I can connect you to the right assistant to look into it properly.",
          suggestedSpeciality: SuggestedSpeciality(
            slug: rule.slug,
            name: specialityName(rule.slug),
            reason: rule.reason,
          ),
        );
      }
    }

    return MedicalQueryResult(
      answer:
          "Here's some general guidance: rest, stay hydrated, and monitor how you feel. If symptoms "
          "persist or worsen, start a consultation and I'll route you to the right specialist.",
      suggestedSpeciality: SuggestedSpeciality(
        slug: 'general-medicine',
        name: specialityName('general-medicine'),
        reason: 'A general physician can assess this first.',
      ),
    );
  }
}

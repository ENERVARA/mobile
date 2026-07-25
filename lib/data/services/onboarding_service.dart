import '../../core/api/api_client.dart';
import '../models/onboarding.dart';

/// Onboarding endpoints (`/api/onboarding/*`). The backend→display type mapping
/// is ported from `src/services/onboardingService.ts` (`mapQuestion`).
class OnboardingService {
  const OnboardingService();

  Future<List<Question>> fetchAllQuestions() async {
    final res = await dio.get('/onboarding/questions');
    final list = (res.data is List) ? res.data as List : const [];
    return list
        .whereType<Map>()
        .map((q) => _mapQuestion(Map<String, dynamic>.from(q)))
        .toList();
  }

  Future<OnboardingMe> fetchMe() async {
    final res = await dio.get('/onboarding/me');
    return OnboardingMe.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<OnboardingMe> submit(List<Map<String, dynamic>> answers) async {
    final res = await dio.post('/onboarding/submit', data: {'answers': answers});
    return OnboardingMe.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Question _mapQuestion(Map<String, dynamic> q) {
    final raw = q['visibleIf'];
    VisibleIfRule? visibleIf;
    if (raw is Map && raw['field'] != null && (raw['field'] as String).isNotEmpty) {
      visibleIf = VisibleIfRule(
        field: raw['field'] as String,
        operator: (raw['operator'] ?? 'equals') as String,
        value: raw['value'],
      );
    }

    final fieldName = (q['fieldName'] ?? '') as String;
    final prompt = (q['questionText'] ?? '') as String;
    final section = q['section'] as String?;
    final module = q['module'] as String?;
    final required = q['required'] == true;
    final options = (q['options'] is List)
        ? (q['options'] as List)
            .map((o) => QuestionOption(value: o.toString(), label: o.toString()))
            .toList()
        : <QuestionOption>[];

    Question base({
      required QuestionType type,
      bool multiselect = false,
      List<QuestionOption> opts = const [],
      num min = 0,
      num max = 100,
      num step = 1,
      num defaultValue = 50,
      String? minLabel,
      String? maxLabel,
      bool multiline = false,
      bool optional = false,
      String? placeholder,
    }) {
      return Question(
        id: fieldName,
        fieldName: fieldName,
        prompt: prompt,
        section: section,
        module: module,
        required: required,
        visibleIf: visibleIf,
        type: type,
        multiselect: multiselect,
        options: opts,
        min: min,
        max: max,
        step: step,
        defaultValue: defaultValue,
        minLabel: minLabel,
        maxLabel: maxLabel,
        multiline: multiline,
        optional: optional,
        placeholder: placeholder,
      );
    }

    if (fieldName == 'city') return base(type: QuestionType.location);

    switch (q['type']) {
      case 'select':
      case 'single_select':
        return base(type: QuestionType.mcq, opts: options);
      case 'multiselect':
      case 'multi_select':
        return base(type: QuestionType.mcq, multiselect: true, opts: options);
      case 'boolean':
        return base(type: QuestionType.yesno);
      case 'number':
        return base(type: QuestionType.slider, min: 0, max: 200, step: 1, defaultValue: 50);
      case 'scale':
        return base(
          type: QuestionType.slider,
          min: 1,
          max: 10,
          step: 1,
          defaultValue: 5,
          minLabel: 'Low',
          maxLabel: 'High',
        );
      case 'date':
        return base(type: QuestionType.date, placeholder: 'YYYY-MM-DD');
      case 'textarea':
        return base(type: QuestionType.text, multiline: true, optional: !required);
      case 'text':
      default:
        return base(type: QuestionType.text);
    }
  }
}

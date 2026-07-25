// Onboarding question + answer models. Ported from `src/types/onboarding.ts`.

enum QuestionType { mcq, slider, yesno, text, date, location }

class VisibleIfRule {
  final String field;
  final String operator; // includes | equals
  final dynamic value;
  const VisibleIfRule({required this.field, required this.operator, this.value});
}

class QuestionOption {
  final String value;
  final String label;
  const QuestionOption({required this.value, required this.label});
}

class Question {
  final String id; // = fieldName
  final String fieldName;
  final String prompt;
  final String? section;
  final String? module;
  final bool required;
  final VisibleIfRule? visibleIf;
  final QuestionType type;

  // mcq
  final bool multiselect;
  final List<QuestionOption> options;

  // slider
  final num min;
  final num max;
  final num step;
  final num defaultValue;
  final String? unit;
  final String? minLabel;
  final String? maxLabel;

  // text
  final String? placeholder;
  final bool multiline;
  final bool optional;

  const Question({
    required this.id,
    required this.fieldName,
    required this.prompt,
    required this.type,
    this.section,
    this.module,
    this.required = false,
    this.visibleIf,
    this.multiselect = false,
    this.options = const [],
    this.min = 0,
    this.max = 100,
    this.step = 1,
    this.defaultValue = 50,
    this.unit,
    this.minLabel,
    this.maxLabel,
    this.placeholder,
    this.multiline = false,
    this.optional = false,
  });
}

class StoredAnswer {
  final String questionId;
  final String fieldName;
  final String questionText;
  final String? section;
  final String? module;
  final dynamic answer;

  const StoredAnswer({
    required this.questionId,
    required this.fieldName,
    required this.questionText,
    this.section,
    this.module,
    this.answer,
  });

  factory StoredAnswer.fromJson(Map<String, dynamic> json) {
    return StoredAnswer(
      questionId: (json['questionId'] ?? json['fieldName'] ?? '').toString(),
      fieldName: (json['fieldName'] ?? '').toString(),
      questionText: (json['questionText'] ?? '').toString(),
      section: json['section'] as String?,
      module: json['module'] as String?,
      answer: json['answer'],
    );
  }
}

class OnboardingMe {
  final List<StoredAnswer> answers;
  final int totalQuestions;
  final int visibleTotal;
  final bool hasBasics;
  final int completeness;

  const OnboardingMe({
    required this.answers,
    required this.totalQuestions,
    required this.visibleTotal,
    required this.hasBasics,
    required this.completeness,
  });

  static const empty = OnboardingMe(
    answers: [],
    totalQuestions: 0,
    visibleTotal: 0,
    hasBasics: false,
    completeness: 0,
  );

  factory OnboardingMe.fromJson(Map<String, dynamic> json) {
    return OnboardingMe(
      answers: (json['answers'] is List)
          ? (json['answers'] as List)
              .whereType<Map>()
              .map((a) => StoredAnswer.fromJson(Map<String, dynamic>.from(a)))
              .toList()
          : const [],
      totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 0,
      visibleTotal: (json['visibleTotal'] as num?)?.toInt() ?? 0,
      hasBasics: json['hasBasics'] == true,
      completeness: (json['completeness'] as num?)?.toInt() ?? 0,
    );
  }
}

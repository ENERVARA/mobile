// Health-profile models. Ported from `src/services/healthProfileService.ts`.
// Enums are kept as raw strings (matching the backend wire values); the UI
// layer maps them to human labels.

class HealthProfileOverview {
  final bool lifestyleDone;
  final bool allergiesDone;
  final bool medicationsDone;
  final bool conditionsDone;
  final bool wellbeingDone;
  final bool surgeriesDone;

  const HealthProfileOverview({
    this.lifestyleDone = false,
    this.allergiesDone = false,
    this.medicationsDone = false,
    this.conditionsDone = false,
    this.wellbeingDone = false,
    this.surgeriesDone = false,
  });

  static const empty = HealthProfileOverview();

  factory HealthProfileOverview.fromJson(Map<String, dynamic> j) => HealthProfileOverview(
        lifestyleDone: j['lifestyleDone'] == true,
        allergiesDone: j['allergiesDone'] == true,
        medicationsDone: j['medicationsDone'] == true,
        conditionsDone: j['conditionsDone'] == true,
        wellbeingDone: j['wellbeingDone'] == true,
        surgeriesDone: j['surgeriesDone'] == true,
      );

  HealthProfileOverview copyWith({
    bool? lifestyleDone,
    bool? allergiesDone,
    bool? medicationsDone,
    bool? conditionsDone,
    bool? wellbeingDone,
    bool? surgeriesDone,
  }) =>
      HealthProfileOverview(
        lifestyleDone: lifestyleDone ?? this.lifestyleDone,
        allergiesDone: allergiesDone ?? this.allergiesDone,
        medicationsDone: medicationsDone ?? this.medicationsDone,
        conditionsDone: conditionsDone ?? this.conditionsDone,
        wellbeingDone: wellbeingDone ?? this.wellbeingDone,
        surgeriesDone: surgeriesDone ?? this.surgeriesDone,
      );
}

class Lifestyle {
  final String? diet; // vegetarian | non_veg | vegan | eggetarian
  final String? exercise; // yes | no | sometimes
  final String? alcohol;
  final String? smoking;
  final num? sleepHours;
  final num? waterCups;

  const Lifestyle({
    this.diet,
    this.exercise,
    this.alcohol,
    this.smoking,
    this.sleepHours,
    this.waterCups,
  });

  static const empty = Lifestyle();

  factory Lifestyle.fromJson(Map<String, dynamic> j) => Lifestyle(
        diet: j['diet'] as String?,
        exercise: j['exercise'] as String?,
        alcohol: j['alcohol'] as String?,
        smoking: j['smoking'] as String?,
        sleepHours: j['sleepHours'] as num?,
        waterCups: j['waterCups'] as num?,
      );

  Lifestyle copyWith({
    String? diet,
    String? exercise,
    String? alcohol,
    String? smoking,
    num? sleepHours,
    num? waterCups,
  }) =>
      Lifestyle(
        diet: diet ?? this.diet,
        exercise: exercise ?? this.exercise,
        alcohol: alcohol ?? this.alcohol,
        smoking: smoking ?? this.smoking,
        sleepHours: sleepHours ?? this.sleepHours,
        waterCups: waterCups ?? this.waterCups,
      );
}

class Wellbeing {
  final num? overallMood;
  final num? stressLevel;
  final num? energyLevel;
  final num? socialConnectedness;
  final num? workAcademicPressure;
  final String? relaxationPractices; // daily | weekly | occasionally | never

  const Wellbeing({
    this.overallMood,
    this.stressLevel,
    this.energyLevel,
    this.socialConnectedness,
    this.workAcademicPressure,
    this.relaxationPractices,
  });

  static const empty = Wellbeing();

  factory Wellbeing.fromJson(Map<String, dynamic> j) => Wellbeing(
        overallMood: j['overallMood'] as num?,
        stressLevel: j['stressLevel'] as num?,
        energyLevel: j['energyLevel'] as num?,
        socialConnectedness: j['socialConnectedness'] as num?,
        workAcademicPressure: j['workAcademicPressure'] as num?,
        relaxationPractices: j['relaxationPractices'] as String?,
      );
}

class Surgery {
  final String id;
  final String surgeryName;
  final int year;
  final String? reason;
  final String? hospital;
  final String currentStatus; // fully_recovered | ongoing_follow_up
  final String createdAt;

  const Surgery({
    required this.id,
    required this.surgeryName,
    required this.year,
    this.reason,
    this.hospital,
    required this.currentStatus,
    required this.createdAt,
  });

  factory Surgery.fromJson(Map<String, dynamic> j) => Surgery(
        id: (j['id'] ?? j['_id'] ?? '').toString(),
        surgeryName: (j['surgeryName'] ?? '') as String,
        year: (j['year'] as num?)?.toInt() ?? 0,
        reason: j['reason'] as String?,
        hospital: j['hospital'] as String?,
        currentStatus: (j['currentStatus'] ?? 'fully_recovered') as String,
        createdAt: (j['createdAt'] ?? '') as String,
      );
}

class Allergy {
  final String id;
  final String allergenName;
  final List<String> reactionTypes;
  final String severity; // mild | moderate | severe | life_threatening
  final String? lastReactionOn;
  final String createdAt;

  const Allergy({
    required this.id,
    required this.allergenName,
    required this.reactionTypes,
    required this.severity,
    this.lastReactionOn,
    required this.createdAt,
  });

  factory Allergy.fromJson(Map<String, dynamic> j) => Allergy(
        id: (j['id'] ?? j['_id'] ?? '').toString(),
        allergenName: (j['allergenName'] ?? '') as String,
        reactionTypes: (j['reactionTypes'] is List)
            ? (j['reactionTypes'] as List).map((e) => e.toString()).toList()
            : const [],
        severity: (j['severity'] ?? 'mild') as String,
        lastReactionOn: j['lastReactionOn'] as String?,
        createdAt: (j['createdAt'] ?? '') as String,
      );
}

class AllergiesResponse {
  final List<Allergy> allergies;
  final String? noKnownAllergiesConfirmedAt;
  const AllergiesResponse({required this.allergies, this.noKnownAllergiesConfirmedAt});

  factory AllergiesResponse.fromJson(Map<String, dynamic> j) => AllergiesResponse(
        allergies: (j['allergies'] is List)
            ? (j['allergies'] as List)
                .whereType<Map>()
                .map((a) => Allergy.fromJson(Map<String, dynamic>.from(a)))
                .toList()
            : const [],
        noKnownAllergiesConfirmedAt: j['noKnownAllergiesConfirmedAt'] as String?,
      );
}

class Medication {
  final String id;
  final String medicationName;
  final String courseType; // short_term | ongoing
  final num? doseAmount;
  final String? doseUnit;
  final num? frequencyCount;
  final String? frequencyPeriod;
  final List<String> timeOfDay;
  final String? withFood;
  final String? reasonOrCondition;
  final String? linkedConditionId;
  final String createdAt;

  const Medication({
    required this.id,
    required this.medicationName,
    required this.courseType,
    this.doseAmount,
    this.doseUnit,
    this.frequencyCount,
    this.frequencyPeriod,
    this.timeOfDay = const [],
    this.withFood,
    this.reasonOrCondition,
    this.linkedConditionId,
    required this.createdAt,
  });

  factory Medication.fromJson(Map<String, dynamic> j) => Medication(
        id: (j['id'] ?? j['_id'] ?? '').toString(),
        medicationName: (j['medicationName'] ?? '') as String,
        courseType: (j['courseType'] ?? 'ongoing') as String,
        doseAmount: j['doseAmount'] as num?,
        doseUnit: j['doseUnit'] as String?,
        frequencyCount: j['frequencyCount'] as num?,
        frequencyPeriod: j['frequencyPeriod'] as String?,
        timeOfDay: (j['timeOfDay'] is List)
            ? (j['timeOfDay'] as List).map((e) => e.toString()).toList()
            : const [],
        withFood: j['withFood'] as String?,
        reasonOrCondition: j['reasonOrCondition'] as String?,
        linkedConditionId: j['linkedConditionId'] as String?,
        createdAt: (j['createdAt'] ?? '') as String,
      );
}

class ConditionCatalogEntry {
  final String code;
  final String displayName;
  const ConditionCatalogEntry({required this.code, required this.displayName});

  factory ConditionCatalogEntry.fromJson(Map<String, dynamic> j) => ConditionCatalogEntry(
        code: (j['code'] ?? '') as String,
        displayName: (j['displayName'] ?? '') as String,
      );
}

class Condition {
  final String id;
  final String conditionCode;
  final String displayName;
  final String? category;
  final String? sinceBucket;
  final String? sinceExactDate;
  final String currentlyTroubling; // yes | no | sometimes
  final bool onMedication;
  final String? linkedMedicationId;
  final String createdAt;

  const Condition({
    required this.id,
    required this.conditionCode,
    required this.displayName,
    this.category,
    this.sinceBucket,
    this.sinceExactDate,
    required this.currentlyTroubling,
    required this.onMedication,
    this.linkedMedicationId,
    required this.createdAt,
  });

  factory Condition.fromJson(Map<String, dynamic> j) => Condition(
        id: (j['id'] ?? j['_id'] ?? '').toString(),
        conditionCode: (j['conditionCode'] ?? '') as String,
        displayName: (j['displayName'] ?? '') as String,
        category: j['category'] as String?,
        sinceBucket: j['sinceBucket'] as String?,
        sinceExactDate: j['sinceExactDate'] as String?,
        currentlyTroubling: (j['currentlyTroubling'] ?? 'no') as String,
        onMedication: j['onMedication'] == true,
        linkedMedicationId: j['linkedMedicationId'] as String?,
        createdAt: (j['createdAt'] ?? '') as String,
      );
}

class ConditionsResponse {
  final List<Condition> conditions;
  final String? noKnownConditionsConfirmedAt;
  const ConditionsResponse({required this.conditions, this.noKnownConditionsConfirmedAt});

  factory ConditionsResponse.fromJson(Map<String, dynamic> j) => ConditionsResponse(
        conditions: (j['conditions'] is List)
            ? (j['conditions'] as List)
                .whereType<Map>()
                .map((c) => Condition.fromJson(Map<String, dynamic>.from(c)))
                .toList()
            : const [],
        noKnownConditionsConfirmedAt: j['noKnownConditionsConfirmedAt'] as String?,
      );
}

/// Grouped by category, e.g. `{ metabolic_cardio: [...], digestive: [...] }`.
typedef ConditionCatalog = Map<String, List<ConditionCatalogEntry>>;

import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Symptom-based entry into the specialist picker (Start new care / the
/// speciality picker). Ported from `src/constants/symptoms.ts`: each symptom
/// maps to one or more of our real, enabled specialities (most-relevant slug
/// first).
class Symptom {
  final String id;
  final String label;
  final IconData icon;
  final List<String> specialitySlugs;
  const Symptom(this.id, this.label, this.icon, this.specialitySlugs);
}

const List<Symptom> kSymptoms = [
  Symptom('cough', 'Cough', PhosphorIconsFill.wind, ['ent', 'general-medicine']),
  Symptom('sneezing', 'Sneezing', PhosphorIconsFill.faceMask, ['ent', 'general-medicine']),
  Symptom('runny-nose', 'Runny nose', PhosphorIconsFill.dropSimple, ['ent', 'general-medicine']),
  Symptom('sore-throat', 'Sore throat', PhosphorIconsFill.microphoneSlash, ['ent', 'general-medicine']),
  Symptom('fever', 'Fever', PhosphorIconsFill.thermometerHot, ['general-medicine']),
  Symptom('tiredness', 'Tiredness', PhosphorIconsFill.moon, ['general-medicine']),
  Symptom('stress', 'Stress', PhosphorIconsFill.brain, ['general-medicine']),
  Symptom('low-mood', 'Low mood', PhosphorIconsFill.smileySad, ['general-medicine']),
  Symptom('backache', 'Backache', PhosphorIconsFill.bone, ['general-medicine']),
  Symptom('heartburn', 'Heartburn', PhosphorIconsFill.fire, ['gastroenterology', 'general-medicine']),
  Symptom('irregular-periods', 'Irregular periods', PhosphorIconsFill.calendarHeart, ['general-medicine']),
  Symptom('hair-fall', 'Hair fall', PhosphorIconsFill.scissors, ['dermatology']),
  Symptom('acne', 'Acne', PhosphorIconsFill.drop, ['dermatology']),
];

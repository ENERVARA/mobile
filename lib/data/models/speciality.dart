/// A medical speciality. Ported from `src/types/speciality.ts`.
class Speciality {
  final String id;
  final String slug;
  final String name;
  final String icon;
  final String description;
  final String shortDescription;
  final String color; // hex string, e.g. "#0BB5A6"
  final int availableDoctors;
  final List<String> commonConditions;
  final List<String> availableTests;
  final String? assistantName;

  const Speciality({
    required this.id,
    required this.slug,
    required this.name,
    required this.icon,
    required this.description,
    required this.shortDescription,
    required this.color,
    required this.availableDoctors,
    required this.commonConditions,
    required this.availableTests,
    this.assistantName,
  });
}

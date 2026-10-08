/// A cheap, honest first guess at what an added document is, from its filename
/// alone. It never decides anything: a hit only pre-fills the "We think this is
/// a … — is that correct?" question, and the patient confirms or changes it.
/// Camera photos ("IMG_2031.jpg") carry no signal and correctly return null.
/// Ported from `features/healthRecords/documentGuess.ts`.
enum DocumentKind { labReport, prescription, other }

const _prescriptionWords = {
  'rx',
  'prescription',
  'prescriptions',
  'presc',
  'medication',
  'medications',
  'medicines',
};

const _labWords = {
  'lab',
  'labs',
  'cbc',
  'lipid',
  'hba1c',
  'a1c',
  'thyroid',
  'tsh',
  'lft',
  'kft',
  'blood',
  'pathology',
  'urine',
  'urinalysis',
  'glucose',
  'haemogram',
  'hemogram',
};

DocumentKind? guessDocumentKind(String fileName) {
  final tokens = fileName
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((t) => t.isNotEmpty)
      .toList();
  final prescription = tokens.any(_prescriptionWords.contains);
  final lab = tokens.any(_labWords.contains);
  if (prescription == lab) return null;
  return prescription ? DocumentKind.prescription : DocumentKind.labReport;
}

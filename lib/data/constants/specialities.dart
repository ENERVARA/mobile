import '../models/speciality.dart';

/// Speciality catalog — ported 1:1 from `src/constants/specialities.ts`.
/// Order: enabled specialities first, then disabled ones.
const List<Speciality> kSpecialities = [
  Speciality(
    id: 'spec-1',
    slug: 'general-medicine',
    name: 'General Medicine',
    icon: 'Stethoscope',
    description:
        'Comprehensive primary care covering diagnosis, treatment, and prevention of a wide range of health conditions. Our general practitioners provide holistic patient care and coordinate with specialists when needed.',
    shortDescription: 'Primary care for all health conditions',
    color: '#0BB5A6',
    availableDoctors: 15,
    commonConditions: [
      'Common Cold & Flu',
      'Fever & Infections',
      'Allergies',
      'Diabetes Management',
      'Hypertension',
      'General Checkups',
    ],
    availableTests: [
      'Complete Blood Count',
      'Blood Sugar',
      'Thyroid Panel',
      'Lipid Profile',
      'Urinalysis',
      'Liver Function Test',
    ],
  ),
  Speciality(
    id: 'spec-10',
    slug: 'gastroenterology',
    name: 'Gastroenterology',
    icon: 'Stomach',
    description:
        'Specialized care for digestive system disorders. Our gastroenterologists diagnose and treat conditions of the stomach, intestines, liver, pancreas, and gallbladder — from acid reflux to inflammatory bowel disease.',
    shortDescription: 'Digestive and gut health',
    color: '#E8A24D',
    availableDoctors: 9,
    commonConditions: [
      'Acid Reflux & GERD',
      'IBS',
      'Inflammatory Bowel Disease',
      'Liver Disease',
      'Gallstones',
      'Ulcers',
    ],
    availableTests: [
      'Endoscopy',
      'Colonoscopy',
      'Liver Function Test',
      'H. pylori Test',
      'Stool Analysis',
      'Abdominal Ultrasound',
    ],
    assistantName: 'Dr. Biome',
  ),
  Speciality(
    id: 'spec-3',
    slug: 'cardiology',
    name: 'Cardiology',
    icon: 'Heartbeat',
    description:
        'Expert cardiovascular care for heart and circulatory system conditions. Our cardiologists provide advanced diagnostics, treatment plans, and ongoing management for heart health.',
    shortDescription: 'Heart and cardiovascular care',
    color: '#F27649',
    availableDoctors: 12,
    commonConditions: [
      'Heart Disease',
      'Arrhythmia',
      'Heart Failure',
      'Coronary Artery Disease',
      'Valve Disorders',
      'High Cholesterol',
    ],
    availableTests: [
      'ECG/EKG',
      'Echocardiogram',
      'Stress Test',
      'Holter Monitor',
      'Cardiac CT',
      'Lipid Panel',
    ],
  ),
  Speciality(
    id: 'spec-4',
    slug: 'dermatology',
    name: 'Dermatology',
    icon: 'SunHorizon',
    description:
        'Comprehensive skin, hair, and nail care. Our dermatologists treat conditions ranging from acne and eczema to skin cancer screening and cosmetic dermatology.',
    shortDescription: 'Skin, hair, and nail health',
    color: '#F5A623',
    availableDoctors: 10,
    commonConditions: [
      'Acne',
      'Eczema',
      'Psoriasis',
      'Skin Allergies',
      'Fungal Infections',
      'Skin Cancer Screening',
    ],
    availableTests: [
      'Skin Biopsy',
      'Patch Testing',
      'Dermoscopy',
      'Wood Lamp Exam',
      'Allergy Panel',
      'Skin Culture',
    ],
  ),
  Speciality(
    id: 'spec-11',
    slug: 'ent',
    name: 'ENT',
    icon: 'Ear',
    description:
        'Specialised care for ear, nose, and throat conditions. Our ENT specialists diagnose and treat issues from chronic sinus infections and hearing loss to vertigo and voice disorders.',
    shortDescription: 'Ear, nose, and throat care',
    color: '#C586E8',
    availableDoctors: 8,
    commonConditions: [
      'Sinus Infections',
      'Tonsillitis',
      'Hearing Loss',
      'Tinnitus',
      'Allergic Rhinitis',
      'Vertigo',
    ],
    availableTests: [
      'Audiometry',
      'Tympanometry',
      'Nasal Endoscopy',
      'Hearing Test',
      'CT Sinus',
      'Allergy Panel',
    ],
  ),
  Speciality(
    id: 'spec-2',
    slug: 'pulmonology',
    name: 'Pulmonology',
    icon: 'Wind',
    description:
        'Specialized care for respiratory and lung conditions. Our pulmonologists diagnose and treat diseases affecting the lungs and breathing, from asthma to complex pulmonary disorders.',
    shortDescription: 'Respiratory and lung health',
    color: '#4DA8DA',
    availableDoctors: 8,
    commonConditions: [
      'Asthma',
      'COPD',
      'Pneumonia',
      'Bronchitis',
      'Sleep Apnea',
      'Pulmonary Fibrosis',
    ],
    availableTests: [
      'Pulmonary Function Test',
      'Chest X-Ray',
      'CT Scan Chest',
      'Spirometry',
      'Bronchoscopy',
      'Arterial Blood Gas',
    ],
  ),
  Speciality(
    id: 'spec-5',
    slug: 'orthopedics',
    name: 'Orthopedics',
    icon: 'Bone',
    description:
        'Specialized musculoskeletal care for bones, joints, muscles, and ligaments. Our orthopedists treat injuries, degenerative conditions, and chronic pain to restore mobility.',
    shortDescription: 'Bone, joint, and muscle care',
    color: '#9B7FE6',
    availableDoctors: 9,
    commonConditions: [
      'Back Pain',
      'Arthritis',
      'Fractures',
      'Sports Injuries',
      'Osteoporosis',
      'Joint Replacement',
    ],
    availableTests: [
      'X-Ray',
      'MRI Scan',
      'Bone Density Test',
      'CT Scan',
      'Joint Aspiration',
      'Nerve Conduction Study',
    ],
  ),
  Speciality(
    id: 'spec-6',
    slug: 'mental-health',
    name: 'Mental Health',
    icon: 'Brain',
    description:
        'Compassionate mental health support including therapy, counseling, and psychiatric care. Our team helps with anxiety, depression, stress, and other mental health conditions.',
    shortDescription: 'Therapy, counseling, and psychiatric care',
    color: '#E85D8A',
    availableDoctors: 14,
    commonConditions: ['Anxiety', 'Depression', 'PTSD', 'OCD', 'Bipolar Disorder', 'Stress Management'],
    availableTests: [
      'Psychological Assessment',
      'Cognitive Screening',
      'Depression Scale',
      'Anxiety Assessment',
      'Sleep Study',
      'Behavioral Analysis',
    ],
  ),
  Speciality(
    id: 'spec-7',
    slug: 'pediatrics',
    name: 'Pediatrics',
    icon: 'Baby',
    description:
        'Dedicated healthcare for infants, children, and adolescents. Our pediatricians provide growth monitoring, vaccinations, developmental assessments, and treatment of childhood illnesses.',
    shortDescription: 'Healthcare for children and adolescents',
    color: '#4DE8D0',
    availableDoctors: 11,
    commonConditions: ['Childhood Infections', 'Growth Disorders', 'Allergies', 'Asthma', 'ADHD', 'Vaccinations'],
    availableTests: [
      'Growth Assessment',
      'Developmental Screening',
      'Hearing Test',
      'Vision Test',
      'Blood Tests',
      'Allergy Testing',
    ],
  ),
  Speciality(
    id: 'spec-8',
    slug: 'neurology',
    name: 'Neurology',
    icon: 'Lightning',
    description:
        'Specialized care for the nervous system including the brain, spinal cord, and nerves. Our neurologists diagnose and treat conditions from migraines to complex neurological disorders.',
    shortDescription: 'Brain and nervous system care',
    color: '#6C7CE6',
    availableDoctors: 7,
    commonConditions: [
      'Migraines',
      'Epilepsy',
      'Multiple Sclerosis',
      "Parkinson's Disease",
      'Neuropathy',
      'Stroke Recovery',
    ],
    availableTests: ['EEG', 'MRI Brain', 'CT Scan', 'Nerve Conduction Study', 'EMG', 'Lumbar Puncture'],
  ),
  Speciality(
    id: 'spec-9',
    slug: 'emotional-health',
    name: 'Emotional Health',
    icon: 'Smiley',
    description:
        'Holistic support for emotional wellbeing, resilience, and self-awareness. Our specialists help with stress, burnout, grief, relationship challenges, and building emotional intelligence for a balanced life.',
    shortDescription: 'Emotional wellbeing and resilience support',
    color: '#7BC8E3',
    availableDoctors: 10,
    commonConditions: [
      'Stress & Burnout',
      'Grief & Loss',
      'Low Self-Esteem',
      'Relationship Issues',
      'Emotional Dysregulation',
      'Life Transitions',
    ],
    availableTests: [
      'Emotional Intelligence Assessment',
      'Stress Screening',
      'Wellbeing Survey',
      'Mood Tracking',
      'Sleep & Stress Audit',
      'Mindfulness Evaluation',
    ],
  ),
];

/// Only these specialities are fully built out for the early-access rollout.
/// Mobile currently only ships General Medicine — every other speciality
/// (including ones the dashboard has already enabled) shows as "Coming soon"
/// here until they're verified on this platform.
const Set<String> kEnabledSpecialitySlugs = {'general-medicine'};

const String kDefaultSpecialitySlug = 'general-medicine';

bool isSpecialityEnabled(String? slug) =>
    slug != null && kEnabledSpecialitySlugs.contains(slug);

Speciality? specialityBySlug(String? slug) {
  if (slug == null) return null;
  for (final s in kSpecialities) {
    if (s.slug == slug) return s;
  }
  return null;
}

/// Real speciality display name for a slug, falling back to General Medicine.
String specialityName(String? slug) {
  final target = isSpecialityEnabled(slug) ? slug : kDefaultSpecialitySlug;
  return specialityBySlug(target)?.name ?? 'General Medicine';
}

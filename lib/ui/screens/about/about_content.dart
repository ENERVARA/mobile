/// Copy for the About / legal pages, transcribed from the marketing site so the
/// mobile app and the web app say exactly the same thing. Structured rather
/// than pre-formatted, so the renderers can style it for the mobile theme.
library;

// ── Models ───────────────────────────────────────────────────────────────────

/// A block inside a legal section: a paragraph, a bullet list, or a contact row.
sealed class LegalBlock {
  const LegalBlock();
}

class Para extends LegalBlock {
  final String text;

  /// Renders in ink rather than ink2 — used for the lead-ins above bullet lists
  /// and for closing statements that shouldn't read as fine print.
  final bool strong;
  const Para(this.text, {this.strong = false});
}

class Bullets extends LegalBlock {
  final List<String> items;
  const Bullets(this.items);
}

/// A tappable email or a plain postal address, depending on [email].
class ContactLine extends LegalBlock {
  final String value;
  final bool email;
  const ContactLine(this.value, {this.email = false});
}

class LegalSection {
  final String heading;
  final List<LegalBlock> blocks;
  const LegalSection(this.heading, this.blocks);
}

class LegalDoc {
  final String title;
  final String version;
  final List<LegalSection> sections;
  const LegalDoc({
    required this.title,
    required this.version,
    required this.sections,
  });
}

// ── Shared strings ───────────────────────────────────────────────────────────

const kCompanyAddress =
    'Zarivenistra Technologies Private Limited — Plot No 18/2, Sector III, '
    'Huda Techno Enclave, Opp to IKEA, Hitech City, Hyderabad - 500081';

const kFounderEmail = 'srivathsa@enervara.com';
const queryEmail = 'grievances@enervara.com';
const kAdminEmail = 'admin@enervara.com';
const kGrievancesEmail = 'grievances@enervara.com';

/// Where the in-app contact form is addressed.
const kSupportEmail = 'support@enervara.com';

// ── About Enervara ───────────────────────────────────────────────────────────

const kAboutHeadlineLead = 'Redefining healthcare through ';
const kAboutHeadlineAccent = 'continuous, intelligent care.';

const kAboutParas = <String>[
  'Healthcare today is fragmented. Patients repeatedly explain their symptoms, '
      'carry scattered reports across consultations, and often navigate an '
      'uncertain path from illness to recovery. At the same time, clinicians '
      'spend valuable consultation time reconstructing incomplete medical '
      'histories instead of focusing on clinical decision making.',
];

const kAboutEmphasis =
    'Enervara is building an AI powered virtual care platform that bridges this gap.';

const kAboutParasAfter = <String>[
  'We combine personalized patient journeys with clinician focused intelligence '
      'to create a continuous healthcare experience — from the first symptom '
      'through structured primary care guidance, specialty specific assistance, '
      'follow up, and long term care continuity. On the clinician side, Enervara '
      'transforms fragmented patient information into organized clinical '
      'summaries, intelligent consultation support, and longitudinal patient '
      'records that enable more efficient, informed care.',
];

// ── Our vision ───────────────────────────────────────────────────────────────

const kVisionHeadline =
    'To build the world’s most trusted AI powered virtual care platform '
    'that seamlessly connects patients and clinicians through continuous, '
    'intelligent, and personalized healthcare.';

const kVisionBody =
    'We envision a future where no patient has to repeat their story, no doctor '
    'has to reconstruct fragmented medical histories, and every healthcare '
    'decision is supported by structured clinical intelligence. Enervara aims '
    'to become the longitudinal care layer that accompanies every individual '
    'from the first symptom to recovery, while empowering clinicians with AI '
    'powered workflows that make care more prepared, efficient, and human.';

const kVisionQuoteLead = 'Healthcare shouldn’t begin with every consultation.';
const kVisionQuoteAccent = 'It should evolve with every interaction.';

// ── Meet the founder ─────────────────────────────────────────────────────────

const kFounderName = 'Srivathsa Ksherasagar';
const kFounderRole = 'Founder & CEO';
const kFounderTagline =
    'Building the future of healthcare through medicine, technology and empathy.';

const kFounderParas = <String>[
  'Srivathsa Ksherasagar is the Founder and CEO of ENERVARA and a budding '
      'physician pursuing his medical education while building the next '
      'generation of AI enabled healthcare infrastructure.',
  'His experience in medical training exposed him to a challenge shared by both '
      'patients and clinicians: fragmented healthcare journeys, repetitive '
      'history taking, disconnected medical records, and workflows that consume '
      'valuable clinical time. These firsthand observations became the '
      'foundation for Enervara.',
  'Bringing together medicine, artificial intelligence, and product design, '
      'Srivathsa envisions a future where technology augments — not replaces — '
      'clinical expertise. His mission is to create a longitudinal care platform '
      'that supports patients from symptom onset to recovery while equipping '
      'clinicians with intelligent workflows that make consultations more '
      'prepared, efficient, and clinically meaningful.',
  'Driven by a belief that continuity should be a fundamental part of '
      'healthcare, he is building Enervara to become the digital care layer '
      'connecting patients and doctors across every stage of the healthcare '
      'journey.',
];

const kFounderQuoteLead = 'Where Clinical Insight Meets ';
const kFounderQuoteAccent = 'Intelligent Innovation.';

/// Optional founder portrait. Absent from the bundle today — the renderer falls
/// back to a monogram, and dropping the file in makes it appear.
const kFounderPhoto = 'assets/images/founder.jpg';

// ── Privacy Policy ───────────────────────────────────────────────────────────

const kPrivacyPolicy = LegalDoc(
  title: 'Privacy Policy',
  version: 'Version 1',
  sections: [
    LegalSection('Introduction', [
      Para('Enervara ("we", "our", or "us") is committed to protecting your '
          'privacy and ensuring the responsible use of your personal data.'),
      Para('This Privacy Policy explains how we collect, use, and safeguard '
          'your information when you use our platform.'),
      Para('By using Enervara, you agree to the practices described in this policy.'),
    ]),
    LegalSection('Information We Collect', [
      Para('We collect information that you provide directly, including:',
          strong: true),
      Bullets([
        'Name, email address, and contact details',
        'Health-related information you choose to share (e.g., symptoms, lifestyle details, wellbeing inputs)',
        'Responses to assessments and conversations with our AI system',
        'Any documents or records you upload (e.g., reports, prescriptions)',
      ]),
      Para('We may also collect limited technical data such as:', strong: true),
      Bullets([
        'Device type',
        'Browser information',
        'Usage patterns (for improving the platform)',
        'Approximate location (latitude/longitude), with your permission — see "Location Data" below',
      ]),
    ]),
    LegalSection('Location Data', [
      Para('With your explicit permission, the Enervara mobile app can detect '
          'when you\'ve moved to a new place, so Nova can give more accurate '
          'guidance for travel-related symptoms — and, soon, to show doctors '
          'near you.', strong: true),
      Para('You choose one of three options, shown when you first sign in and '
          'changeable anytime from the location button in the app:', strong: true),
      Bullets([
        'Continuous — location updates automatically, even when the app is closed, only when you move to a new area (not continuously tracked in between)',
        'Only when app is open — location updates only while you\'re actively using Enervara',
        'Don\'t allow — location is never accessed',
      ]),
      Para('Location data is stored securely and is not used for advertising '
          'and is not sold to third parties.'),
      Para('You can change your choice at any time from the location button '
          'in the app, or by revoking the permission from your device\'s '
          'Settings — the app continues to work without it.'),
    ]),
    LegalSection('How We Use Your Information', [
      Para('We use your data to:', strong: true),
      Bullets([
        'Provide personalized health guidance',
        'Generate structured health insights based on your inputs',
        'Improve our AI models and platform performance',
        'Facilitate connections with healthcare professionals (when applicable)',
        'Communicate important updates or responses',
      ]),
    ]),
    LegalSection('How Your Health Data Is Handled', [
      Para('Your health-related data is:', strong: true),
      Bullets([
        'Used only to provide guidance and improve your experience',
        'Processed using clinically informed AI systems',
        'Not sold to third parties',
      ]),
      Para('We do not use your personal health data for advertising purposes.'),
    ]),
    LegalSection('Data Sharing', [
      Para('We may share your data only in the following cases:', strong: true),
      Bullets([
        'With healthcare professionals, if you choose to connect with them',
        'With trusted service providers (e.g., hosting, email delivery) under strict confidentiality',
        'When required by law or regulatory authorities',
      ]),
      Para('We do not sell or rent your personal data.'),
    ]),
    LegalSection('Data Security', [
      Para('We implement appropriate technical and organizational measures to '
          'protect your data, including:', strong: true),
      Bullets([
        'Secure data storage',
        'Encryption where applicable',
        'Restricted access controls',
      ]),
      Para('While we strive to protect your data, no system can guarantee '
          'absolute security.'),
    ]),
    LegalSection('Your Rights (DPDP Act, India)', [
      Para('Under applicable laws, you have the right to:', strong: true),
      Bullets([
        'Access your personal data',
        'Request correction or deletion',
        'Withdraw consent for data processing',
        'Request information on how your data is used',
      ]),
      Para('To exercise these rights, contact us at:'),
      ContactLine(kAdminEmail, email: true),
    ]),
    LegalSection('Data Retention', [
      Para('We retain your data only as long as necessary to provide our '
          'services and comply with legal obligations.'),
      Para('You may request deletion of your data at any time.'),
    ]),
    LegalSection('Cookies and Tracking', [
      Para('We may use cookies or similar technologies to:', strong: true),
      Bullets([
        'Improve user experience',
        'Analyze platform usage',
      ]),
      Para('You can control cookie settings through your browser.'),
    ]),
    LegalSection('Important Disclaimer', [
      Para('Enervara provides AI-powered health guidance for informational '
          'purposes only.'),
      Para('It is not a substitute for professional medical advice, diagnosis, '
          'or treatment.'),
      Para('Always consult a qualified healthcare provider for medical concerns.'),
    ]),
    LegalSection('Updates to This Policy', [
      Para('We may update this Privacy Policy from time to time.'),
      Para('Any changes will be reflected on this page with an updated date.'),
    ]),
    LegalSection('Contact Us', [
      Para('If you have any questions about this Privacy Policy or your data:',
          strong: true),
      ContactLine(queryEmail, email: true),
      ContactLine(kCompanyAddress),
    ]),
  ],
);

// ── Terms of Service ─────────────────────────────────────────────────────────

const kTermsOfService = LegalDoc(
  title: 'Terms of Service',
  version: 'Version 1',
  sections: [
    LegalSection('Acceptance of Terms', [
      Para('By accessing or using Enervara ("the Platform", "we", "our", "us"), '
          'you agree to be bound by these Terms of Service.'),
      Para('If you do not agree, please do not use the Platform.'),
    ]),
    LegalSection('Description of Service', [
      Para('Enervara provides AI-powered health guidance based on user-provided '
          'information, including:', strong: true),
      Bullets([
        'Health-related inputs and responses',
        'Lifestyle and wellbeing data shared by users',
        'Uploaded documents or medical records (if any)',
      ]),
      Para('The Platform may also facilitate connections with healthcare '
          'professionals.'),
    ]),
    LegalSection('Not Medical Advice', [
      Para('Enervara does not provide medical advice, diagnosis, or treatment.'),
      Para('All information provided through the Platform is for informational '
          'and guidance purposes only.'),
      Para('You should always consult a qualified healthcare professional '
          'before making medical decisions.'),
    ]),
    LegalSection('User Responsibilities', [
      Para('By using Enervara, you agree to:', strong: true),
      Bullets([
        'Provide accurate and truthful information',
        'Use the Platform only for lawful purposes',
        'Not misuse, copy, or attempt to reverse engineer the system',
        'Not rely solely on the Platform for critical medical decisions',
      ]),
    ]),
    LegalSection('Eligibility', [
      Para('You must be at least 18 years old to use the Platform.'),
      Para('If you are using the Platform on behalf of someone else, you '
          'confirm that you have appropriate authorization.'),
    ]),
    LegalSection('Account and Access', [
      Para('You may be required to create an account to access certain features.'),
      Para('You are responsible for:', strong: true),
      Bullets([
        'Maintaining the confidentiality of your account',
        'All activities under your account',
      ]),
      Para('We reserve the right to suspend or terminate access if misuse is '
          'detected.'),
    ]),
    LegalSection('Data and Privacy', [
      Para('Your use of the Platform is also governed by our Privacy Policy.'),
      Para('By using Enervara, you consent to the collection and use of your '
          'data as described in that policy.'),
    ]),
    LegalSection('AI Limitations', [
      Para('The Platform uses AI systems that:', strong: true),
      Bullets([
        'Generate insights based on available data',
        'May not always be complete, accurate, or up to date',
      ]),
      Para('You acknowledge that:', strong: true),
      Bullets([
        'Outputs may vary',
        'AI guidance should not replace professional judgment',
      ]),
    ]),
    LegalSection('Third-Party Services', [
      Para('Enervara may integrate or connect you with third-party services, '
          'including healthcare providers.'),
      Para('We are not responsible for:', strong: true),
      Bullets([
        'The actions or advice of third-party professionals',
        'External platforms or services',
      ]),
    ]),
    LegalSection('Intellectual Property', [
      Para('All content, design, and technology on the Platform are owned by '
          'Enervara.'),
      Para('You may not:', strong: true),
      Bullets([
        'Copy, distribute, or reproduce any part of the Platform',
        'Use our content for commercial purposes without permission',
      ]),
    ]),
    LegalSection('Limitation of Liability', [
      Para('To the fullest extent permitted by law:'),
      Para('Enervara shall not be liable for:', strong: true),
      Bullets([
        'Any decisions made based on Platform outputs',
        'Any direct, indirect, or incidental damages',
        'Health outcomes resulting from reliance on the Platform',
      ]),
    ]),
    LegalSection('Indemnification', [
      Para('You agree to indemnify and hold Enervara harmless from any claims '
          'arising from:', strong: true),
      Bullets([
        'Misuse of the Platform',
        'Violation of these Terms',
        'Inaccurate information provided by you',
      ]),
    ]),
    LegalSection('Termination', [
      Para('We may suspend or terminate your access at any time if:', strong: true),
      Bullets([
        'You violate these Terms',
        'Misuse is detected',
      ]),
      Para('You may stop using the Platform at any time.'),
    ]),
    LegalSection('Changes to Terms', [
      Para('We may update these Terms from time to time.'),
      Para('Continued use of the Platform after updates constitutes acceptance '
          'of the revised Terms.'),
    ]),
    LegalSection('Governing Law', [
      Para('These Terms shall be governed by the laws of India.'),
      Para('Any disputes shall be subject to the jurisdiction of courts in '
          'Hyderabad, Telangana.'),
    ]),
    LegalSection('Contact', [
      Para('For any questions regarding these Terms:', strong: true),
      ContactLine(queryEmail, email: true),
      ContactLine(kCompanyAddress),
    ]),
  ],
);

// ── Security ─────────────────────────────────────────────────────────────────

const kSecurityDoc = LegalDoc(
  title: 'Security',
  version: 'Version 1',
  sections: [
    LegalSection('Overview', [
      Para('Enervara is designed with a security-first and privacy-focused '
          'approach. We are committed to protecting personal and health-related '
          'data through appropriate technical and organizational measures.'),
      Para('Our practices are aligned with applicable data protection laws, '
          'including the Digital Personal Data Protection Act, 2023 (India), '
          'and follow industry-standard security principles.'),
    ]),
    LegalSection('Data Protection Framework', [
      Para('We implement safeguards to ensure that personal data is:', strong: true),
      Bullets([
        'Collected for specific and lawful purposes',
        'Processed in a fair and transparent manner',
        'Limited to what is necessary for the intended purpose',
        'Protected against unauthorized access, disclosure, alteration, or loss',
      ]),
      Para('Data handling practices are regularly reviewed to maintain '
          'compliance with evolving regulatory and security requirements.'),
    ]),
    LegalSection('Data Collection and Minimization', [
      Para('We follow a principle of data minimization. Only the information '
          'necessary to provide health guidance and platform functionality is '
          'collected.'),
      Para('Health-related data is collected solely based on user-provided '
          'inputs, uploaded records, or explicitly connected data sources '
          '(where applicable).'),
      Para('We do not engage in passive or undisclosed collection of sensitive '
          'personal data.'),
    ]),
    LegalSection('Encryption and Secure Transmission', [
      Para('We use encryption and secure communication protocols to protect '
          'data:', strong: true),
      Bullets([
        'Data in transit is protected using secure encryption protocols (e.g., HTTPS/TLS)',
        'Sensitive data is secured using encryption mechanisms where applicable',
        'Secure APIs and communication layers are used to prevent interception or unauthorized access',
      ]),
    ]),
    LegalSection('Access Controls', [
      Para('Access to personal and health data is strictly controlled:',
          strong: true),
      Bullets([
        'Role-based access controls are implemented',
        'Access is restricted to authorized personnel only',
        'Access logs and monitoring mechanisms are maintained to detect and prevent unauthorized usage',
      ]),
    ]),
    LegalSection('Data Storage and Infrastructure', [
      Para('User data is stored on secure infrastructure provided by trusted '
          'cloud service providers.'),
      Para('We ensure that:', strong: true),
      Bullets([
        'Data is stored in controlled environments',
        'Infrastructure providers adhere to recognized security standards',
        'Appropriate safeguards are in place to prevent data breaches and unauthorized access',
      ]),
    ]),
    LegalSection('Third-Party Processors', [
      Para('We may engage third-party service providers for infrastructure, '
          'communication, and platform operations.'),
      Para('All such providers are:', strong: true),
      Bullets([
        'Contractually bound to maintain confidentiality',
        'Required to implement appropriate security safeguards',
        'Restricted from using personal data for purposes beyond specified services',
      ]),
    ]),
    LegalSection('AI and Data Processing', [
      Para('Enervara uses AI systems to process user-provided information and '
          'generate health guidance.'),
      Para('These systems:', strong: true),
      Bullets([
        'Operate only on data provided by the user or authorized sources',
        'Do not independently access external personal data',
        'Are designed to function within controlled and secure environments',
      ]),
      Para('AI outputs are generated based on available inputs and are subject '
          'to system limitations.'),
    ]),
    LegalSection('Data Retention and Deletion', [
      Para('We retain personal data only for as long as necessary to:',
          strong: true),
      Bullets([
        'Provide services',
        'Fulfill legal and regulatory obligations',
      ]),
      Para('Users may request deletion of their data, subject to applicable '
          'legal requirements.'),
    ]),
    LegalSection('User Rights', [
      Para('In accordance with applicable laws, including the DPDP Act, users '
          'have the right to:', strong: true),
      Bullets([
        'Access their personal data',
        'Request correction of inaccurate data',
        'Request deletion of their data',
        'Withdraw consent for processing',
      ]),
      Para('Requests may be submitted through the contact details provided '
          'below.'),
    ]),
    LegalSection('Incident Response and Breach Management', [
      Para('We maintain internal procedures to identify, manage, and respond to '
          'security incidents.'),
      Para('In the event of a data breach, we will:', strong: true),
      Bullets([
        'Take appropriate containment and mitigation measures',
        'Notify affected users and authorities as required under applicable laws',
        'Document and review the incident to prevent recurrence',
      ]),
    ]),
    LegalSection('Continuous Improvement', [
      Para('Security practices are continuously reviewed and updated to address '
          'emerging threats and regulatory changes.'),
      Para('We aim to maintain a high standard of data protection as the '
          'platform evolves.'),
    ]),
    LegalSection('Responsible Use', [
      Para('Enervara is designed to support health understanding and '
          'decision-making.'),
      Para('It does not replace professional medical advice, diagnosis, or '
          'treatment. Users are encouraged to consult qualified healthcare '
          'professionals for clinical decisions.'),
    ]),
    LegalSection('Contact', [
      Para('For security-related queries or concerns:', strong: true),
      ContactLine(kGrievancesEmail, email: true),
      ContactLine(kCompanyAddress),
    ]),
  ],
);

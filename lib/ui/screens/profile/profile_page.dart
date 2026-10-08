import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/context_ext.dart';
import '../../../core/ui/app_messenger.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/services/location_service.dart';
import '../../../state/auth_provider.dart';
import '../../../state/health_profile_provider.dart';
import '../../../state/onboarding_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/location_toggle_button.dart';
import 'sections/allergies_section.dart';
import 'sections/conditions_section.dart';
import 'sections/lifestyle_section.dart';
import 'sections/medications_section.dart';
import 'sections/past_surgery_section.dart';
import 'sections/wellbeing_section.dart';
import 'widgets/profile_parts.dart';

const _sexOptions = <({String value, String label})>[
  (value: 'male', label: 'Male'),
  (value: 'female', label: 'Female'),
  (value: 'intersex', label: 'Intersex'),
  (value: 'prefer_not_to_say', label: 'Prefer not to say'),
];

/// My Profile — ported from `src/features/profile/pages/ProfilePage.tsx`,
/// stacked into a single mobile column: hero head → "Building your care
/// picture" progress → Basic Information → Health Metrics → health modules →
/// privacy note → danger zone.
class ProfilePage extends ConsumerStatefulWidget {
  /// When true (first-run health setup), the page greets the new user, scrolls
  /// to Basic Information and highlights it, prompting them to fill it in.
  final bool setup;
  const ProfilePage({super.key, this.setup = false});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _secondaryPhone = TextEditingController();

  String? _sex;
  String? _state;
  String? _city;
  DateTime? _dob;
  bool _dirty = false;
  bool _hydrated = false;

  // ── First-run health-setup state ──
  final _scroll = ScrollController();
  final _basicInfoKey = GlobalKey();
  late bool _setupActive = widget.setup;
  bool _highlight = false;

  /// state name → cities, loaded from the bundled india-locations.json.
  Map<String, List<String>> _locations = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(healthProfileProvider.notifier).load();
      ref.read(onboardingProvider.notifier).load();
      if (_setupActive) _runSetupIntro();
    });
    for (final c in [_firstName, _lastName, _phone, _secondaryPhone]) {
      c.addListener(_markDirty);
    }
    _loadLocations();
  }

  /// First-run: scroll to Basic Information and pulse a highlight so the new
  /// user knows exactly where to start filling in their details.
  Future<void> _runSetupIntro() async {
    await Future<void>.delayed(const Duration(milliseconds: 550));
    final ctx = _basicInfoKey.currentContext;
    if (ctx != null && ctx.mounted) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    }
    if (!mounted) return;
    setState(() => _highlight = true);
    await Future<void>.delayed(const Duration(milliseconds: 2400));
    if (mounted) setState(() => _highlight = false);
  }

  /// Dismiss the setup prompt and continue into the app.
  void _finishSetup() {
    setState(() => _setupActive = false);
    context.go('/dashboard');
  }

  /// Basic Information is the only section with a manual Save, so track edits
  /// to keep the button disabled until something actually changed.
  void _markDirty() {
    if (_hydrated && !_dirty) setState(() => _dirty = true);
  }

  Future<void> _loadLocations() async {
    try {
      final raw = await rootBundle.loadString('assets/data/india-locations.json');
      final decoded = jsonDecode(raw);
      final states = (decoded is Map ? decoded['states'] : null);
      if (states is List) {
        final map = <String, List<String>>{};
        for (final s in states.whereType<Map>()) {
          final name = s['name']?.toString();
          if (name == null) continue;
          map[name] = (s['cities'] is List)
              ? (s['cities'] as List).map((c) => c.toString()).toList()
              : <String>[];
        }
        if (mounted) setState(() => _locations = map);
      }
    } catch (_) {
      /* locations are optional — the selects simply stay empty */
    }
  }

  void _hydrateFromUser() {
    final user = ref.read(authProvider).user;
    if (user == null || _hydrated) return;
    _firstName.text = user.firstName;
    _lastName.text = user.lastName;
    _phone.text = user.phone ?? '';
    _secondaryPhone.text = user.secondaryPhone ?? '';
    _sex = user.sex;
    _state = user.state;
    _city = user.city;
    _dob = Formatters.tryParse(user.dateOfBirth ?? '');
    _hydrated = true;
  }

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _phone, _secondaryPhone]) {
      c.removeListener(_markDirty);
    }
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _secondaryPhone.dispose();
    _scroll.dispose();
    super.dispose();
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Select your date of birth',
    );
    if (picked != null) setState(() { _dob = picked; _dirty = true; });
  }

  Future<void> _save() async {
    final payload = <String, dynamic>{
      'firstName': _firstName.text.trim(),
      'lastName': _lastName.text.trim(),
      'phone': _phone.text.trim(),
      'secondaryPhone': _secondaryPhone.text.trim(),
      if (_dob != null) 'dateOfBirth': _iso(_dob!),
      if (_sex != null) 'sex': _sex,
      if (_state != null) 'state': _state,
      if (_city != null) 'city': _city,
    };
    try {
      await ref.read(authProvider.notifier).updateMe(payload);
      if (!mounted) return;
      setState(() => _dirty = false);
      AppMessenger.success('Profile updated');
    } catch (_) {
      /* the API interceptor already toasted */
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account'),
        content: const Text(
          "Permanently delete your account and all your data. This can't be undone after the grace period.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.coral)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(authProvider.notifier).deleteAccount();
      await ref.read(authProvider.notifier).logout();
      if (!mounted) return;
      AppMessenger.success(
        'Your account is scheduled for deletion. Log back in within 14 days to cancel.',
      );
      context.go('/login');
    } catch (_) {/* toasted */}
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final user = ref.watch(authProvider).user;
    final health = ref.watch(healthProfileProvider);
    final onboarding = ref.watch(onboardingProvider);
    _hydrateFromUser();

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Height / weight / BMI come from the onboarding answers (read-only here).
    String? answerFor(String field) {
      for (final a in onboarding.me.answers) {
        if (a.fieldName == field && a.answer != null) return a.answer.toString();
      }
      return null;
    }

    final heightCm = answerFor('height_cm');
    final weightKg = answerFor('weight_kg');
    final bmi = computeBmi(
      heightCm: double.tryParse(heightCm ?? ''),
      weightKg: double.tryParse(weightKg ?? ''),
    );

    // 7 sections: Basic Info, Lifestyle, Allergies, Medications, Conditions,
    // Wellbeing, Surgeries.
    final basicInfoDone = onboarding.me.hasBasics && (user.sex?.isNotEmpty ?? false);
    final o = health.overview;
    final done = [
      basicInfoDone,
      o.lifestyleDone,
      o.allergiesDone,
      o.medicationsDone,
      o.conditionsDone,
      o.wellbeingDone,
      o.surgeriesDone,
    ].where((x) => x).length;
    final isComplete = done >= 7;

    final createdAt = Formatters.tryParse(user.createdAt ?? '');
    final cities = _locations[_state] ?? const <String>[];
    final age = _dob != null ? Formatters.ageFromDob(_iso(_dob!)) : null;

    return SafeArea(
      top: false,
      child: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          // ── First-run health-setup banner ──
          if (_setupActive) ...[
            _SetupBanner(
              firstName: user.firstName.trim().isNotEmpty ? user.firstName.trim() : null,
              onDone: _finishSetup,
            ),
            const SizedBox(height: 16),
          ],

          // ── Title ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My Profile',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: t.ink)),
                    const SizedBox(height: 4),
                    Text(
                      'Your personal details and health profile — keep them updated so Nova can personalise your care.',
                      style: TextStyle(fontSize: 13.3, height: 1.45, color: t.ink2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── About Enervara — big and unmissable ──
          GestureDetector(
            onTap: () => context.push('/about'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.line),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(PhosphorIconsFill.info, size: 22, color: AppColors.teal),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('About Enervara',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700, color: t.ink)),
                        const SizedBox(height: 2),
                        Text('Privacy policy, terms & support',
                            style: TextStyle(fontSize: 12.2, color: t.ink3)),
                      ],
                    ),
                  ),
                  Icon(PhosphorIconsBold.caretRight, size: 18, color: t.ink3),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Hero head ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.teal, AppColors.cyan],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    user.initial,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: t.ink)),
                      const SizedBox(height: 6),
                      _Meta(icon: PhosphorIconsRegular.envelopeSimple, text: user.email),
                      if ((user.phone ?? '').isNotEmpty)
                        _Meta(icon: PhosphorIconsRegular.phone, text: user.phone!),
                      _Meta(
                        icon: PhosphorIconsRegular.calendarBlank,
                        text: 'Since ${createdAt != null ? Formatters.dateMedium(createdAt) : '—'}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: t.line),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(PhosphorIconsRegular.signOut, size: 15, color: AppColors.coral),
                      SizedBox(width: 8),
                      Text(
                        'Log out',
                        style: TextStyle(fontSize: 13.76, fontWeight: FontWeight.w600, color: AppColors.coral),
                      ),
                    ],
                  ),
                ),
              ),
            ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── "Building your care picture" ──
          _CarePictureCard(done: done, isComplete: isComplete),
          const SizedBox(height: 16),

          // ── Basic Information ──
          AnimatedContainer(
            key: _basicInfoKey,
            duration: const Duration(milliseconds: 400),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _highlight ? AppColors.teal : Colors.transparent,
                width: 2,
              ),
              boxShadow: _highlight
                  ? [
                      BoxShadow(
                        color: AppColors.teal.withValues(alpha: 0.28),
                        blurRadius: 22,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: InfoCard(
            icon: PhosphorIconsRegular.identificationCard,
            title: 'Basic Information',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: LabeledField(
                        label: 'First Name',
                        controller: _firstName,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LabeledField(label: 'Last Name', controller: _lastName),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LabeledField(
                  label: 'Email',
                  initialValue: user.email,
                  enabled: false,
                  locked: true,
                ),
                const SizedBox(height: 12),
                LabeledField(
                  label: 'Phone number',
                  controller: _phone,
                  hint: '+91 98765 43210',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                LabeledField(
                  label: 'Secondary phone (optional)',
                  controller: _secondaryPhone,
                  hint: '+91 98765 43210',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                LabeledField(
                  label: age != null ? 'Date of birth — Age $age' : 'Date of birth',
                  readOnly: true,
                  onTap: _pickDob,
                  hint: 'dd / mm / yyyy',
                  controller: TextEditingController(text: _dob != null ? _iso(_dob!) : ''),
                ),
                const SizedBox(height: 12),
                LabeledSelect(
                  label: 'State',
                  value: _state,
                  placeholder: 'Select…',
                  options: [
                    for (final name in (_locations.keys.toList()..sort()))
                      (value: name, label: name),
                  ],
                  onChanged: (v) => setState(() {
                    _state = v;
                    if (_city != null && !(_locations[v]?.contains(_city) ?? false)) _city = null;
                    _dirty = true;
                  }),
                ),
                const SizedBox(height: 12),
                LabeledSelect(
                  label: 'City',
                  value: _city,
                  enabled: _state != null,
                  placeholder: _state != null ? 'Select…' : 'Pick a state first',
                  options: [for (final c in cities) (value: c, label: c)],
                  onChanged: (v) => setState(() { _city = v; _dirty = true; }),
                ),
                const SizedBox(height: 12),
                LabeledSelect(
                  label: 'Sex',
                  value: _sex,
                  placeholder: 'Select…',
                  options: _sexOptions,
                  onChanged: (v) => setState(() { _sex = v; _dirty = true; }),
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Save Changes',
                  height: 42,
                  loading: ref.watch(authProvider).isLoading,
                  onPressed: _dirty ? _save : null,
                ),
              ],
            ),
          ),
          ),
          const SizedBox(height: 16),

          // ── Health Metrics ──
          InfoCard(
            icon: PhosphorIconsRegular.heartbeat,
            title: 'Health Metrics',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: MetricTile(label: 'Height', unit: 'cm', value: heightCm)),
                    const SizedBox(width: 10),
                    Expanded(child: MetricTile(label: 'Weight', unit: 'kg', value: weightKg)),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      RichText(
                        text: TextSpan(children: [
                          TextSpan(
                            text: bmi != null ? bmi.value.toStringAsFixed(1) : '—',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              color: t.ink,
                            ),
                          ),
                          TextSpan(
                            text: '  BMI',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.ink3),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 2),
                      Text(bmi?.category ?? 'Add data', style: TextStyle(fontSize: 12, color: t.ink2)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'These values come from your health questionnaire.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, height: 1.5, color: t.ink3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Location card ──
          _LocationCard(),
          const SizedBox(height: 16),

          // ── Health modules ──
          const LifestyleSection(),
          const SizedBox(height: 16),
          const WellbeingSection(),
          const SizedBox(height: 16),
          const AllergiesSection(),
          const SizedBox(height: 16),
          const MedicationsSection(),
          const SizedBox(height: 16),
          const PastSurgerySection(),
          const SizedBox(height: 16),
          const ConditionsSection(),
          const SizedBox(height: 16),
          const _ReproductiveHealthPlaceholder(),

          const SizedBox(height: 16),
          Text(
            "Your health data is private, encrypted at rest, and used only to personalise Nova and your doctor's handoff — never sold or shared.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, height: 1.55, color: t.ink3),
          ),
          const SizedBox(height: 20),

          // ── Danger zone ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.coral.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.coral.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Delete account',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: t.ink)),
                const SizedBox(height: 3),
                Text(
                  "Permanently delete your account and all your data. This can't be undone after the grace period.",
                  style: TextStyle(fontSize: 11.8, height: 1.5, color: t.ink2),
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Delete account',
                  variant: AppButtonVariant.danger,
                  height: 42,
                  onPressed: _confirmDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// First-run greeting shown above the profile form, prompting the new user to
/// complete their details. "Do this later" continues straight into the app.
class _SetupBanner extends StatelessWidget {
  final String? firstName;
  final VoidCallback onDone;
  const _SetupBanner({required this.firstName, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppGradients.brandDiagonal,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.teal.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(PhosphorIconsFill.identificationCard, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  firstName != null ? 'Welcome, $firstName! 👋' : 'Welcome to Enervara! 👋',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "Let's complete your health profile so Nova can personalise every answer. "
            'Fill in your details below — you can add allergies, medications and more too.',
            style: TextStyle(fontSize: 13.5, height: 1.5, color: Colors.white),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onDone,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Do this later',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.tealD)),
                    const SizedBox(width: 6),
                    const Icon(PhosphorIconsBold.arrowRight, size: 14, color: AppColors.tealD),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationCard extends StatefulWidget {
  const _LocationCard();

  @override
  State<_LocationCard> createState() => _LocationCardState();
}

class _LocationCardState extends State<_LocationCard> {
  LocationAccessMode _mode = LocationAccessMode.off;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final mode = await LocationService.instance.currentMode();
    if (mounted) setState(() => _mode = mode);
  }

  String _statusText(LocationAccessMode mode) {
    switch (mode) {
      case LocationAccessMode.off:
        return 'Off';
      case LocationAccessMode.whileInUse:
        return 'On';
      case LocationAccessMode.continuous:
        return 'On';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isOn = _mode != LocationAccessMode.off;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  PhosphorIconsRegular.mapPin,
                  size: 16,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Location',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: t.ink,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isOn
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusText(_mode),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isOn ? AppColors.success : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Used to flag illnesses going around your area and to spot symptoms that may be linked to recent travel. We store approximate coordinates only — never a continuous trail.",
            style: TextStyle(fontSize: 12.8, height: 1.55, color: t.ink2),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.soft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Saved Aug 30, 2026',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  '12.976, 80.262',
                  style: TextStyle(fontSize: 12.6, color: t.ink2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          LocationToggleButton(compact: false, label: 'Update location'),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(icon, size: 13, color: t.ink3),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.2, color: t.ink2),
            ),
          ),
        ],
      ),
    );
  }
}

/// The lavender (or emerald, when complete) "Building your care picture" hero.
class _CarePictureCard extends StatelessWidget {
  final int done;
  final bool isComplete;
  const _CarePictureCard({required this.done, required this.isComplete});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = context.isDark;
    final accent = isComplete ? const Color(0xFF10B981) : AppColors.lav;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [accent.withValues(alpha: 0.22), t.card]
              : [accent.withValues(alpha: 0.10), t.card],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.28),
            blurRadius: 40,
            spreadRadius: -8,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isComplete ? PhosphorIconsRegular.checkCircle : PhosphorIconsRegular.clipboardText,
              size: 22,
              color: accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Building your care picture',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.ink)),
                const SizedBox(height: 3),
                Text('$done of 7 sections complete',
                    style: TextStyle(fontSize: 12.8, color: t.ink2)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: done / 7,
                          minHeight: 8,
                          backgroundColor: dark
                              ? Colors.white.withValues(alpha: 0.10)
                              : Colors.black.withValues(alpha: 0.05),
                          valueColor: AlwaysStoppedAnimation(accent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('$done/7',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Reproductive health — the backend model exists but no form is built yet, so
/// this mirrors the web's static placeholder card.
class _ReproductiveHealthPlaceholder extends StatelessWidget {
  const _ReproductiveHealthPlaceholder();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.lav.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(PhosphorIconsFill.heart, size: 18, color: AppColors.lav),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  'Reproductive Health',
                  style: TextStyle(fontSize: 16.8, fontWeight: FontWeight.w600, color: t.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(14)),
            child: Text(
              'Coming soon — this section will let you track cycle, pregnancy and related history.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.4, height: 1.45, color: t.ink2),
            ),
          ),
        ],
      ),
    );
  }
}

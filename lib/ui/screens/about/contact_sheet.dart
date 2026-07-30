import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/context_ext.dart';
import '../../../core/ui/app_messenger.dart';
import '../../../core/utils/validators.dart';
import '../../../state/auth_provider.dart';
import '../../widgets/app_button.dart';
import 'about_content.dart';
import 'widgets/about_parts.dart';

/// The site's "Get in touch" modal, as a bottom sheet.
Future<void> showContactSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const ContactSheet(),
  );
}

class ContactSheet extends ConsumerStatefulWidget {
  const ContactSheet({super.key});

  @override
  ConsumerState<ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends ConsumerState<ContactSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  final _message = TextEditingController();

  bool _consent = false;
  bool _consentError = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Prefill from the signed-in profile — they shouldn't retype what we know.
    final user = ref.read(authProvider).user;
    _name = TextEditingController(text: user?.fullName ?? '');
    _email = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final formOk = _form.currentState?.validate() ?? false;
    setState(() => _consentError = !_consent);
    if (!formOk || !_consent) return;

    setState(() => _sending = true);
    final name = _name.text.trim();
    final sent = await openMailTo(
      kSupportEmail,
      subject: 'Enervara — message from $name',
      body: 'Name: $name\n'
          'Email: ${_email.text.trim()}\n\n'
          '${_message.text.trim()}\n',
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (!sent) return;

    Navigator.of(context).pop();
    AppMessenger.success('Your message is ready to send in your mail app');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: t.line,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(child: Eyebrow('Contact')),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, size: 20, color: t.ink3),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Get in touch',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
                          color: t.ink,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Tell us what’s on your mind. We read every message.',
                        style: TextStyle(fontSize: 13.6, height: 1.5, color: t.ink2),
                      ),
                      const SizedBox(height: 20),

                      _Field(
                        label: 'Name',
                        controller: _name,
                        hint: 'Your name',
                        textInputAction: TextInputAction.next,
                        validator: (v) => Validators.name(v, 'Name'),
                      ),
                      const SizedBox(height: 14),
                      _Field(
                        label: 'Email',
                        controller: _email,
                        hint: 'you@example.com',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: Validators.email,
                      ),
                      const SizedBox(height: 14),
                      _Field(
                        label: 'Message',
                        controller: _message,
                        hint: 'What would you like to share?',
                        maxLines: 5,
                        validator: (v) => Validators.required(v, 'Message'),
                      ),
                      const SizedBox(height: 16),

                      _ConsentRow(
                        value: _consent,
                        error: _consentError,
                        onChanged: (v) => setState(() {
                          _consent = v;
                          if (v) _consentError = false;
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 14, 20, 18 + MediaQuery.viewPaddingOf(context).bottom),
              child: Column(
                children: [
                  AppButton(
                    label: 'Send Message',
                    icon: PhosphorIconsBold.arrowRight,
                    height: 50,
                    loading: _sending,
                    onPressed: _send,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Opens your mail app with the message addressed to our team.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: t.ink3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;

  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.textInputAction,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: t.ink2),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          minLines: maxLines,
          keyboardType: keyboardType ??
              (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
          textInputAction: textInputAction,
          textCapitalization:
              maxLines > 1 ? TextCapitalization.sentences : TextCapitalization.words,
          validator: validator,
          style: TextStyle(fontSize: 14, height: 1.45, color: t.ink),
          decoration: InputDecoration(hintText: hint, isDense: true),
        ),
      ],
    );
  }
}

/// The site's consent checkbox, which gates the send button.
class _ConsentRow extends StatelessWidget {
  final bool value;
  final bool error;
  final ValueChanged<bool> onChanged;

  const _ConsentRow({
    required this.value,
    required this.error,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 1, right: 10),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: value ? AppColors.teal : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: value
                          ? AppColors.teal
                          : (error ? AppColors.danger : t.line),
                      width: 1.5,
                    ),
                  ),
                  child: value
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                Expanded(
                  child: Text(
                    'I agree to share the information above with Enervara so they '
                    'can respond to my message.',
                    style: TextStyle(fontSize: 12.6, height: 1.45, color: t.ink2),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (error)
          Padding(
            padding: const EdgeInsets.only(left: 30, top: 4),
            child: Text(
              'Please agree before sending',
              style: TextStyle(fontSize: 11.5, color: AppColors.danger),
            ),
          ),
      ],
    );
  }
}

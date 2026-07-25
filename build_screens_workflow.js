export const meta = {
  name: 'enervara-mobile-screens',
  description: 'Port every Enervara mobile-view screen from React to Flutter against the validated foundation',
  phases: [{ title: 'Build screens', detail: 'one agent per screen group, reading web source + contract' }],
}

const CONTRACT = 'c:/Aksel/Project/Enervara/dashboard/mobile_app/PORTING_CONTRACT.md'
const SRC = 'c:/Aksel/Project/Enervara/dashboard/src'
const DART = 'c:/Aksel/Project/Enervara/dashboard/mobile_app/lib/ui/screens'

const common = `You are porting part of the Enervara React web app to Flutter, reproducing the MOBILE view exactly (same layout, spacing, colours, copy, behaviour).

FIRST read the contract at ${CONTRACT} — it lists every foundation API (theme tokens, AppColors, AppGradients, widgets, providers, models, constants, utils) you must use. Use ONLY those APIs; do not invent new theme constants/models/providers. If unsure of an exact signature, Read the relevant foundation file under c:/Aksel/Project/Enervara/dashboard/mobile_app/lib (e.g. lib/ui/widgets/app_button.dart, lib/state/<x>_provider.dart, lib/data/models/<x>.dart).

Then Read the listed web source file(s) to match the design faithfully, and WRITE the listed Dart target file(s) with the Write tool.

Hard rules:
- In-shell pages (dashboard, specialities, speciality detail, reports, report detail, history, profile, emergency) MUST return a body widget with NO Scaffold/AppBar (AppShell provides it). Make the body scrollable with bottom padding 90 and horizontal padding 16, wrapped in SafeArea(top:false).
- Full-screen pages (auth, onboarding, nova) return their own Scaffold.
- Riverpod: ConsumerWidget/ConsumerStatefulWidget; ref.watch(provider) / ref.read(provider.notifier).method().
- go_router: context.go for tab routes, context.push for detail/nova/emergency, context.pop to go back.
- Valid null-safe Dart 3. Every identifier you reference MUST exist in the foundation. Prefer const where possible.
- Do NOT run flutter/dart commands. Do NOT edit files outside your target list. Do NOT touch pubspec or foundation files.

Return a SHORT summary: files written + any place you were unsure of a foundation API (name it precisely) so it can be verified.`

const tasks = [
  {
    label: 'auth',
    prompt: `${common}

SCREEN GROUP: Authentication (5 pages + shared scaffold).
Web source to read: ${SRC}/features/auth/pages/AuthPage.tsx, ${SRC}/features/auth/pages/ForgotPasswordPage.tsx, ${SRC}/features/auth/pages/ResetPasswordPage.tsx, ${SRC}/features/auth/pages/VerifySignupPage.tsx, ${SRC}/features/auth/components/AuthLayout.tsx, ${SRC}/features/auth/components/AuthParts.tsx
Write these Dart files:
- ${DART}/auth/auth_scaffold.dart — a shared AuthScaffold widget: brand gradient top area with Logo + "Enervara", then a white rounded card holding the form; scrollable, keyboard-safe.
- ${DART}/auth/login_page.dart — LoginPage (email + password). Submits via authProvider.login. Links: "Forgot password?" -> context.push('/forgot-password'); "Sign up" -> context.go('/signup'). Include a Google button that calls AppMessenger.info('Google sign-in needs additional setup on mobile.'). On success the router auto-redirects.
- ${DART}/auth/signup_page.dart — SignupPage (firstName, lastName, email, phone, password). Submits via authProvider.requestSignup; after success show a "Check your email" confirmation state (uses authState.pendingSignupEmail). Link to login.
- ${DART}/auth/forgot_password_page.dart — email -> authProvider.forgotPassword -> success state ("If that email exists, a reset link was sent").
- ${DART}/auth/reset_password_page.dart — ResetPasswordPage({String? token}); new password + confirm -> authProvider.resetPassword(token, pw).
- ${DART}/auth/verify_signup_page.dart — VerifySignupPage({String? token}); a "Verify my account" button -> authProvider.verifySignup(token); show verifying/success/error states.
The web AuthPage is a single component toggling login/signup by mode — split into the two pages above. IGNORE the desktop AuthShowcase carousel (hidden on mobile). Keep constructors matching the router: LoginPage(), SignupPage(), ForgotPasswordPage(), ResetPasswordPage({super.key, this.token}), VerifySignupPage({super.key, this.token}).`,
  },
  {
    label: 'dashboard',
    prompt: `${common}

SCREEN GROUP: Dashboard + its cards.
Web source to read: ${SRC}/features/dashboard/pages/DashboardPage.tsx, ${SRC}/features/dashboard/components/StartCareCard.tsx, ${SRC}/features/dashboard/components/ResumeCareCard.tsx, ${SRC}/features/dashboard/components/AskQueryCard.tsx, ${SRC}/features/dashboard/components/SpecialityPickerModal.tsx, ${SRC}/features/onboarding/components/BasicOnboardingModal.tsx
Write these Dart files:
- ${DART}/dashboard/dashboard_page.dart — DashboardPage (const). Greets the user by first name (authProvider.user). Shows the three cards in a column. On init: ref.read(chatProvider.notifier).loadRecentConversations(); if onboardingProvider is loaded and !me.hasBasics, show the BasicOnboarding bottom sheet once.
- ${DART}/dashboard/widgets/start_care_card.dart — "Start new care" card. Tapping opens a speciality picker bottom sheet (build it here or in speciality_picker_sheet.dart) listing enabled specialities; picking one -> context.push('/nova?speciality=<slug>').
- ${DART}/dashboard/widgets/resume_care_card.dart — "Resume previous care" card reading chatProvider.recentConversations; each row shows the speciality icon/name + timeAgo(lastMessageAt); tap -> context.push('/nova?speciality=<slug>'). Empty state if none.
- ${DART}/dashboard/widgets/ask_query_card.dart — "Ask a medical query" interactive card. A small chat thread + composer; on submit call MedicalQueryService().askMedicalQuery(text) (import data/services/medical_query_service.dart), show the answer, and if suggestedSpeciality present show a CTA button -> context.push('/nova?speciality=<slug>'). Include a few example prompt chips.
- ${DART}/dashboard/widgets/speciality_picker_sheet.dart — the reusable speciality picker bottom sheet (used by StartCareCard). Export a function showSpecialityPicker(context).
- ${DART}/dashboard/widgets/basic_onboarding_sheet.dart — the basics bottom sheet (height cm + weight kg) with a live BMI preview via computeBmi; submit via onboardingProvider.submit([{fieldName:'height_cm',answer:...},{fieldName:'weight_kg',answer:...}]).`,
  },
  {
    label: 'specialities',
    prompt: `${common}

SCREEN GROUP: Specialities list.
Web source to read: ${SRC}/features/specialities/pages/SpecialitiesPage.tsx
Write: ${DART}/specialities/specialities_page.dart — SpecialitiesPage (const, in-shell body). PageHeader("Specialities", ...). Render kSpecialities as cards (use AppCard + SpecialityIcon with AppColors.hex(color) + PillBadge avail/soon). Enabled specialities (isSpecialityEnabled) are tappable -> context.push('/specialities/<slug>') and show an "Available" PillBadge; disabled ones are greyed (opacity ~0.55) with a "Soon" PillBadge and not tappable.`,
  },
  {
    label: 'speciality-detail',
    prompt: `${common}

SCREEN GROUP: Speciality detail.
Web source to read: ${SRC}/features/specialities/pages/SpecialityDetailPage.tsx
Write: ${DART}/specialities/speciality_detail_page.dart — SpecialityDetailPage({required String slug}) (in-shell body). Look up specialityBySlug(slug). Hero header: use specialityImageAsset(slug, isDark:context.isDark) from data/constants/speciality_images.dart via Image.asset (with a dark gradient scrim + the speciality name over it); if the asset is null, fall back to a coloured header using AppColors.hex(speciality.color). Show shortDescription/description, availableDoctors, commonConditions as chips, availableTests as a list. A prominent "Ask Nova" AppButton -> context.push('/nova?speciality=<slug>') (only for enabled specialities; disabled show a "Coming soon" note). Include a back button (context.pop) at the top of the body.`,
  },
  {
    label: 'reports',
    prompt: `${common}

SCREEN GROUP: Reports list + detail + upload.
Web source to read: ${SRC}/features/reports/pages/ReportsPage.tsx, ${SRC}/features/reports/pages/ReportDetailPage.tsx, ${SRC}/components/shared/FileUploader.tsx
Write these Dart files:
- ${DART}/reports/reports_page.dart — ReportsPage (const, in-shell body). On init ref.read(reportsProvider.notifier).load(). List reportsProvider.reports (newest first) as cards: icon by mime (filePdf/image), fileName, category PillBadge, Formatters.fileSize(sizeBytes), timeAgo(createdAt). Tap -> context.push('/reports/<id>'). An "Upload" AppButton opens the upload sheet. Empty state when none.
- ${DART}/reports/widgets/upload_sheet.dart — a bottom sheet: pick a file via file_picker (allowed pdf/jpg/jpeg/png/dcm) OR an image via image_picker, choose a category (reportCategories), then ref.read(reportsProvider.notifier).upload(path, fileName:, category:, onProgress:) with a live progress bar. Toast success/error.
- ${DART}/reports/report_detail_page.dart — ReportDetailPage({required String id}) (in-shell body). Find the report in reportsProvider.reports. Fetch bytes via ref.read(reportsServiceProvider).fetchBlob(id) (FutureBuilder). If image -> Image.memory; if pdf -> show a file icon + metadata + note that PDFs open externally. A delete action (confirm dialog) -> reportsProvider.removeReport(id) then context.pop. Back button at top.`,
  },
  {
    label: 'history',
    prompt: `${common}

SCREEN GROUP: History (ComingSoon-gated).
Web source to read: ${SRC}/features/history/pages/HistoryPage.tsx
Write: ${DART}/history/history_page.dart — HistoryPage (const, in-shell body). Reproduce the web: a teaser of report/history content behind a ComingSoon overlay. Use a Stack: the (blurred/greyed) teaser list underneath + ComingSoon(asOverlay:true) on top. Load reportsProvider on init for the teaser data.`,
  },
  {
    label: 'emergency',
    prompt: `${common}

SCREEN GROUP: Emergency.
Web source to read: ${SRC}/features/emergency/pages/EmergencyPage.tsx
Write: ${DART}/emergency/emergency_page.dart — EmergencyPage (const, in-shell body). Reproduce the emergency screen: a large prominent call button that dials AppConfig.emergencyNumber (import core/config/app_config.dart) using url_launcher (launchUrl(Uri.parse('tel:112'))), plus the emergency guidance/info sections. Use coral accents. Include a back button (context.pop) since it is pushed.`,
  },
  {
    label: 'profile',
    prompt: `${common}

SCREEN GROUP: Profile — the biggest. Shell + Basic Info + all health-profile sections + form modals.
Web source to read: ${SRC}/features/profile/pages/ProfilePage.tsx, ${SRC}/features/profile/components/LifestyleSection.tsx, ${SRC}/features/profile/components/WellbeingSection.tsx, ${SRC}/features/profile/components/AllergiesSection.tsx, ${SRC}/features/profile/components/AllergyFormModal.tsx, ${SRC}/features/profile/components/MedicationsSection.tsx, ${SRC}/features/profile/components/MedicationFormModal.tsx, ${SRC}/features/profile/components/ConditionsSection.tsx, ${SRC}/features/profile/components/ConditionFormModal.tsx, ${SRC}/features/profile/components/PastSurgerySection.tsx, ${SRC}/features/profile/components/SurgeryFormModal.tsx, ${SRC}/features/profile/components/ReproductiveHealthPlaceholder.tsx
Write these Dart files:
- ${DART}/profile/profile_page.dart — ProfilePage (const, in-shell body). On init: ref.read(healthProfileProvider.notifier).load(). Sections in order: Basic Information (editable form: firstName,lastName,phone,secondaryPhone,dateOfBirth(date picker),sex(SegmentedControl male/female/intersex/prefer_not_to_say)) with a Save button -> authProvider.updateMe({...}); the "X of 5 sections complete" tracker (healthProfileProvider.modulesComplete); then the health module cards (Lifestyle, Wellbeing, Allergies, Medications, Conditions, Past Surgery, Reproductive placeholder). At the bottom: Sign out (authProvider.logout) and Delete account (confirm -> authProvider.deleteAccount then logout).
- ${DART}/profile/sections/lifestyle_section.dart, wellbeing_section.dart, allergies_section.dart, medications_section.dart, conditions_section.dart, past_surgery_section.dart, reproductive_placeholder.dart — each an in-card section reading healthProfileProvider and opening its form sheet.
- ${DART}/profile/modals/allergy_form_sheet.dart, medication_form_sheet.dart, condition_form_sheet.dart, surgery_form_sheet.dart — bottom sheets that add/edit via the healthProfileProvider methods (build the patch Map matching the model fields; enums are raw strings — e.g. severity 'mild'/'moderate'/'severe'/'life_threatening', courseType 'short_term'/'ongoing', currentStatus 'fully_recovered'/'ongoing_follow_up'). Conditions use healthProfileProvider.conditionsCatalog (Map<category,List<ConditionCatalogEntry>>) for the picker.
Lifestyle autosaves (debounced) via saveLifestyle; Wellbeing via saveWellbeing. Allergies/Conditions have a "No known ..." confirm action (confirmNoAllergies/confirmNoConditions). Keep it clean; match the web's card layout.`,
  },
  {
    label: 'nova-chat',
    prompt: `${common}

SCREEN GROUP: Nova chat (fullscreen). This is the redesigned white-bg + gradient-accent chat.
Web source to read: ${SRC}/components/nova/ChatPanel.tsx, ${SRC}/components/nova/MessageList.tsx, ${SRC}/components/nova/blocks/BlockRenderer.tsx, ${SRC}/components/nova/blocks/SummaryBlock.tsx, ${SRC}/components/nova/blocks/ConditionCards.tsx, ${SRC}/components/nova/blocks/WarningBanner.tsx, ${SRC}/components/nova/blocks/NextStepsList.tsx, ${SRC}/components/nova/blocks/BulletList.tsx, ${SRC}/components/nova/blocks/KeyPoints.tsx, ${SRC}/components/nova/blocks/DecisionBanner.tsx, ${SRC}/components/nova/blocks/OtcMedications.tsx, ${SRC}/components/nova/NovaThinking.tsx, ${SRC}/components/nova/RichText.tsx, ${SRC}/components/nova/MediaAnalysisCard.tsx, ${SRC}/components/nova/ImageMessageBubble.tsx
Write these Dart files:
- ${DART}/nova/nova_chat_page.dart — NovaChatPage({String? specialitySlug}) — own Scaffold, fullscreen. On init: ref.read(novaUiProvider.notifier).open(slug: specialitySlug). Header row: back (context.pop), Nova title + subtitle, "New chat" (novaUiProvider.newChat). Body: NovaOrb(preset chat) + greeting (novaGreeting(firstName)) + quick-action chips (kNovaDefaultQuick) when there are no messages; otherwise the MessageList. Then the composer.
- ${DART}/nova/widgets/message_list.dart — renders chatProvider.messages mapped to PanelMessage (assistant role -> 'nova'). Nova bubbles = solid teal (AppColors.teal, white text), rounded [4,16,16,16]; user bubbles = solid #2CB0C8 (const Color(0xFF2CB0C8), white text), rounded [16,4,16,16]; Nova avatar = teal circle w/ white Logo(size 15); user avatar = soft circle w/ initial. Show a live streaming bubble from chatProvider.streamingContent + streamingBlocks while isStreaming; show NovaThinking dots when isStreaming and nothing streamed yet. Timestamps via Formatters.messageTime. Auto-scroll to bottom.
- ${DART}/nova/widgets/nova_blocks.dart — a BlockRenderer widget switching over MessageBlock subtypes (SummaryBlock -> teal text bubble; ConditionListBlock -> card with condition rows + likelihood pill coloured by high/mod/low; WarningBlock -> coral-tinted banner; NextStepsBlock -> checklist card; BulletListBlock; KeyPointsBlock; DecisionBlock -> verdict banner; OtcMedicationsBlock -> med cards; FollowUpQuestionsBlock -> render nothing). Match the web block components.
- ${DART}/nova/widgets/nova_composer.dart — text field + attach (image_picker -> novaUiProvider.sendImage(path, caption, mime)) + send (novaUiProvider.send(text)); while chatProvider.isStreaming show a Stop button (chatProvider.stopStream). Teal send button. Show chatProvider.streamError inline if set.
- ${DART}/nova/widgets/nova_thinking.dart — the animated three-dot "thinking" indicator.
Match the redesign exactly: white/card background, teal Nova bubbles, cyan user bubbles, gradient orb.`,
  },
  {
    label: 'onboarding',
    prompt: `${common}

SCREEN GROUP: Onboarding (mandatory post-signup completion).
Web source to read: ${SRC}/features/onboarding/pages/OnboardingPage.tsx, ${SRC}/features/onboarding/components/BasicOnboardingModal.tsx
Write: ${DART}/onboarding/onboarding_page.dart — OnboardingPage (const, own Scaffold, fullscreen). A clean welcome + a short form to complete the mandatory profile: date of birth (date picker) and sex (SegmentedControl male/female/intersex/prefer_not_to_say). On submit: ref.read(authProvider.notifier).updateMe({'dateOfBirth': iso, 'sex': value}) then ref.read(authProvider.notifier).completeOnboarding() (router then redirects to /dashboard). Brand gradient header + Logo. If the web OnboardingPage differs, follow its intent but ensure completeOnboarding() is called so the onboarding gate resolves.`,
  },
]

phase('Build screens')
const results = await parallel(
  tasks.map((t) => () => agent(t.prompt, { label: t.label, phase: 'Build screens', agentType: 'general-purpose' })),
)

return tasks.map((t, i) => ({ screen: t.label, summary: results[i] }))

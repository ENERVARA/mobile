# Enervara mobile_app — Screen Porting Contract

You are porting ONE screen from the React web app (`../src`, i.e. `c:\Aksel\Project\Enervara\dashboard\src`) to Flutter, faithfully reproducing the **mobile view** (`max-md:` Tailwind variants + the mobile shell). Match layout, spacing, colours, copy, and behaviour. Use ONLY the foundation APIs below — do NOT invent new theme constants, models, or providers, and do NOT run `flutter`/`dart` commands.

## Golden rules
- **In-shell pages** (dashboard, specialities, speciality detail, history, reports, report detail, profile, emergency) return a **body widget with NO Scaffold/AppBar** — the `AppShell` already provides the Scaffold, header, drawer and bottom nav. Make the body scrollable (`ListView`/`SingleChildScrollView` inside `SafeArea(top: false, ...)`) with bottom padding `90` so content clears the bottom tab bar. Standard horizontal page padding is `16`.
- **Full-screen pages** (auth, onboarding, nova) return their own `Scaffold`.
- Use Riverpod: extend `ConsumerWidget` or `ConsumerStatefulWidget`; read state with `ref.watch(provider)`, call actions with `ref.read(provider.notifier).method()`.
- Navigate with go_router: `context.go('/path')` for bottom-tab destinations, `context.push('/path')` for detail/nova/emergency, `context.pop()` to go back. Import `package:go_router/go_router.dart`.
- Toasts: `AppMessenger.error('...')` / `AppMessenger.success('...')` from `core/ui/app_messenger.dart`.
- Match the file path you were told to write. Keep it self-contained; small private helper widgets in the same file are fine.

## Theme access (`import '../../core/theme/context_ext.dart';` — adjust depth)
- `context.tokens` → `AppTokens` with: `.ink` (primary text), `.ink2` (secondary), `.ink3` (muted), `.appBg` (page bg), `.card` (surface), `.soft` (subtle fill), `.line` (hairline border).
- `context.isDark` → bool. `context.text` → TextTheme.
- `AppColors` (`core/theme/app_colors.dart`): `teal (#0BB5A6)`, `tealD (#099488)`, `tealDD`, `cyan (#2CB0C8)`, `lav (#8168C4)`, `coral (#F26440)`, `amber (#E0A51F)`, `success`, `danger`, `brandCoral`, `brandPink`, `brandLavender`, and `AppColors.hex('#RRGGBB')`.
- `AppGradients` (`core/theme/app_gradients.dart`): `brandDiagonal`, `hubHero`, `miniBrand`, `feature`, `tealCyan`, `barFill`, `brand` (all `LinearGradient`).

### Tailwind → Flutter token map (the web uses these classes)
`text-ink`→tokens.ink, `text-ink-2`→ink2, `text-ink-3`→ink3, `bg-card`→card, `bg-soft`→soft, `bg-app-bg`→appBg, `border-line`→line, `text-teal`→AppColors.teal, `text-teal-d`→tealD, `bg-teal`→teal, `text-coral`→coral, `text-lav`→lav, `text-amber`→amber. Rounded: `rounded-[18px]`→18, `rounded-[20px]`→20, `rounded-full`→999. Font sizes are in rem: multiply by 16 (e.g. `text-[0.86rem]`→13.8≈14, `text-[1.8rem]`→28).

## Shared widgets (`ui/widgets/…`)
- `Logo(size: 34, white: false)` — brand mark; `white:true` = white silhouette (on gradients).
- `NovaOrb(preset: OrbPreset.sidebar|chat|hub, size:)` — animated dot-sphere.
- `AppButton(label:, onPressed:, variant: AppButtonVariant.primary|gradient|outline|ghost|danger, loading:, expand: true, icon:, height: 50)`.
- `AppCard(child:, padding: EdgeInsets.all(16), onTap:, color:, borderColor:, radius: 18, shadow:)`.
- `PillBadge(variant: PillVariant.avail|soon|green|amber|gray, label:, dot:)`.
- `SegmentedControl<T>(options: [SegmentOption(value,label)], value:, onChanged:, disabled:)`.
- `PageHeader(title:, subtitle:, action:)` — the top title block for in-shell pages.
- `ComingSoon(title:, description:, asOverlay:)` — `asOverlay:true` wraps in `Positioned.fill` (put inside a `Stack`).
- `SpecialityIcon(icon: <name>, size:, color:)` and static `SpecialityIcon.resolve(name)` → IconData.
- Icons: `import 'package:phosphor_flutter/phosphor_flutter.dart';` then `PhosphorIconsRegular.x`, `PhosphorIconsFill.x`, `PhosphorIconsDuotone.x`, `PhosphorIconsBold.x` (camelCase icon names, e.g. `heartbeat`, `clipboardText`, `paperPlaneRight`, `arrowLeft`, `x`, `plus`, `trash`, `pencilSimple`, `uploadSimple`, `filePdf`, `image`).

## Constants (`data/constants/…`)
- `kSpecialities` (List<Speciality>), `kEnabledSpecialitySlugs` (Set), `isSpecialityEnabled(slug)`, `specialityBySlug(slug)`, `specialityName(slug)`, `kDefaultSpecialitySlug`.
- `novaGreeting([name])`, `kNovaDefaultQuestion`, `kNovaDefaultQuick` (List<QuickAction{IconData icon,String label,String text}>).

## Models (`data/models/…`)
- `User{id,email,firstName,lastName,phone?,secondaryPhone?,dateOfBirth?,sex?,onboardingCompleted,isVerified,provider?}` + `.fullName`, `.initial`.
- `Speciality{id,slug,name,icon,description,shortDescription,color(hex),availableDoctors,commonConditions[],availableTests[],assistantName?}`.
- `Report{id,fileName,mimeType,sizeBytes,category,createdAt}` + `.isPdf/.isImage`; `reportCategories`.
- `ChatConversation{id,sessionId,specialitySlug,title,lastMessageAt,createdAt,blocksEnabled}`; `ChatMessage{id,role,content,blocks?,analysis?,imageFileId?,imageMimeType?,localPreviewUrl?,uploadProgress?,followupQuestions?,createdAt}`.
- `PanelMessage{id,role('nova'|'user'),text,time,blocks?,imageFileId?,localPreviewUrl?,uploadProgress?,analysis?}` + `.isUser`.
- MessageBlock subtypes: `SummaryBlock(text)`, `ConditionListBlock(conditions:[ConditionEntry{name,likelihood?,description?}])`, `WarningBlock{text?,severity?}`, `NextStepsBlock(steps)`, `BulletListBlock{title?,items}`, `KeyPointsBlock(points)`, `DecisionBlock{verdict,rationale}`, `LabTestsBlock(tests:[LabTest{name,reason,urgency?}])`, `OtcMedicationsBlock(medications:[OtcMedication{name,purpose,dosage?,caution?}])`, `FollowUpQuestionsBlock(questions)`, `AnswerStateBlock{showDoctorSummary}`, `UnknownBlock{type,data,text?}`.
- `SoapNote{subjective,objective,assessment,plan,unavailable[],generatedAt?}` + `.toPlainText()` — the "Show this to your doctor" export, regenerated per call from the full thread.
- `MessageAnalysis{category,route,caption,extractedFacts[],mimeType,sizeBytes,filename,storageUri}` + `.isDocument`, `.categoryLabel`, `.isEmpty` — the image endpoint's `media` object (accepted as `media` or `analysis`). `category` is one of clinical_photo|general_photo|lab_report|radiology_report|document|other_medical_document|unknown; `route` is multimodal_llm|document_extraction. `storageUri` is a backend reference, never a fetchable URL.
- `ApiError{code,message,requestId,status}` + `.isRetryable` — the parsed `{code,message,request_id}` envelope, attached as `DioException.error`. `UPSTREAM_UNAVAILABLE`/`RATE_LIMITED` and transport failures auto-retry twice with a 1 s → 2 s back-off; `FormData` bodies and stream responses never do.
- `AnswerStateBlock` is a **control** block: never rendered, always last in a turn. Its `showDoctorSummary` flag is sticky for the conversation and gates the SOAP-note action.
- Onboarding: `Question{id,fieldName,prompt,type(QuestionType.mcq|slider|yesno|text|date|location),options[QuestionOption{value,label}],multiselect,min,max,step,defaultValue,minLabel,maxLabel,multiline,section,module,visibleIf}`, `OnboardingMe{answers[StoredAnswer{fieldName,questionText,answer,module}],totalQuestions,visibleTotal,hasBasics,completeness}`.
- Health: `Lifestyle{diet?,exercise?,alcohol?,smoking?,sleepHours?,waterCups?}`, `Wellbeing{overallMood?,stressLevel?,energyLevel?,socialConnectedness?,workAcademicPressure?,relaxationPractices?}`, `Allergy{id,allergenName,reactionTypes[],severity,lastReactionOn?}`, `Medication{id,medicationName,courseType,doseAmount?,doseUnit?,frequencyCount?,frequencyPeriod?,timeOfDay[],withFood?,reasonOrCondition?,linkedConditionId?}`, `Condition{id,conditionCode,displayName,category?,sinceBucket?,sinceExactDate?,currentlyTroubling,onMedication,linkedMedicationId?}`, `ConditionCatalogEntry{code,displayName}`, `Surgery{id,surgeryName,year,reason?,hospital?,currentStatus}`, `HealthProfileOverview{lifestyleDone,allergiesDone,medicationsDone,conditionsDone,wellbeingDone,surgeriesDone}`.

## Providers (`state/…`)
- `authProvider` → `AuthState{user,isAuthenticated,isHydrated,isLoading,error,pendingSignupEmail}`. Notifier: `login(id,pw)`, `requestSignup(firstName,lastName,email,phone,password)`, `verifySignup(token)`, `forgotPassword(email)`, `resetPassword(token,newPassword)`, `updateMe(Map)`, `completeOnboarding()`, `deleteAccount()`, `logout()`.
- `themeProvider` → `ThemeMode`. Notifier: `toggle()`, `setMode()`, `.isDark`.
- `chatProvider` → `ChatState{conversations,recentConversations,activeConversationId,messages,isStreaming,streamingContent,streamingBlocks,isSendingImage,imageUploadProgress,streamError,isLoadingMessages,showDoctorSummary,...}`. Notifier: `loadConversations(slug)`, `loadRecentConversations(limit)`, `createConversation(slug)`, `openConversation(id)`, `sendMessage(text)`, `sendImageMessage(filePath,query,mime)`, `generateSoapNote()`, `renameConversation`, `deleteConversation`, `stopStream()`, `clearActive()`.
- `novaUiProvider` → `NovaUiState{specialitySlug,preparing,sending}`. Notifier: `open({slug})`, `send(text)`, `sendImage(filePath,query,mime)`, `newChat()`.
- `onboardingProvider` → `OnboardingUiState{me,isLoaded,isLoading,error}`. Notifier: `load()`, `submit(List<Map>)`.
- `healthProfileProvider` → `HealthProfileState{overview,lifestyle,wellbeing,allergies,medications,conditions,conditionsCatalog,surgeries,noKnownAllergiesConfirmedAt,noKnownConditionsConfirmedAt,isLoaded,isLoading,modulesComplete}`. Notifier: `load()`, `saveLifestyle(Map)`, `saveWellbeing(Map)`, `addAllergy/editAllergy/removeAllergy/confirmNoAllergies`, `addMedication/editMedication/removeMedication`, `addCondition/editCondition/removeCondition/confirmNoConditions`, `addSurgery/editSurgery/removeSurgery`.
- `reportsProvider` → `ReportsState{reports,isLoaded,isLoading}`. Notifier: `load()`, `upload(filePath,{fileName,category,onProgress})`, `addReport(r)`, `removeReport(id)`. For the JWT blob: `ref.read(reportsServiceProvider).fetchBlob(id)` → `Uint8List`.

## Utils
- `Formatters.timeAgo(DateTime)`, `Formatters.messageTime(DateTime)`, `Formatters.dateMedium(DateTime)`, `Formatters.fileSize(int)`, `Formatters.ageFromDob(iso)`, `Formatters.tryParse(iso)`; `computeBmi(heightCm:, weightKg:)` → `BmiResult{value,category}`. `Validators.email/password/name/required`.

## Behaviour parity notes
- Only 5 specialities are enabled (`general-medicine, gastroenterology, cardiology, dermatology, ent`); disabled ones render greyed/`feature-disabled` (opacity ~0.55, not tappable to chat).
- Reports/History both read `reportsProvider`; History is gated behind a `ComingSoon` overlay.
- Nova mobile is a fullscreen page. The composer streams via `novaUiProvider.send`; a Stop button appears while `chatProvider.isStreaming`.

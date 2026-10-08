import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../state/nova_ui_provider.dart';
import '../../../widgets/app_modal.dart';
import 'specialist_finder.dart';

/// Closes the picker, then opens Nova on the NEXT frame. Opening Nova mutates
/// `novaUiProvider`, which `AppShell`'s own `ref.listen` reacts to by starting
/// an animation — doing that in the same synchronous tap handler that just
/// popped this dialog's route risks racing the dialog's own pop-triggered
/// rebuild (a classic "markNeedsBuild during build" failure mode). Deferring
/// to `addPostFrameCallback` guarantees the dialog has fully torn down first.
void _closeThenOpenNova(BuildContext ctx, void Function() openNova) {
  Navigator.of(ctx).pop();
  WidgetsBinding.instance.addPostFrameCallback((_) => openNova());
}

/// "Start new care" modal — choosing a specialist redirects into that
/// speciality's assistant (Nova, focused). Ported from `StartCareCard.tsx`'s
/// modal (`max-md:p-5`).
Future<void> showStartCarePicker(BuildContext context, WidgetRef ref) {
  return showAppModal<void>(
    context,
    maxWidth: 672,
    padding: const EdgeInsets.all(20),
    builder: (ctx) => SpecialistFinder(
      rootTitle: 'Choose a specialist',
      rootSubtitle:
          "Pick the area you'd like help with and Nova connects you to that assistant.",
      onPick: (slug) => _closeThenOpenNova(
        ctx,
        () => ref.read(novaUiProvider.notifier).openFullscreen(slug),
      ),
    ),
  );
}

/// The "Where shall we start?" speciality picker (`SpecialityPickerModal.tsx`),
/// shown once per fresh session on Home and from My Care's "Start new care".
/// Choosing one opens Nova focused on that speciality.
Future<void> showSpecialityPickerModal(BuildContext context, WidgetRef ref) {
  return showAppModal<void>(
    context,
    maxWidth: 672,
    builder: (ctx) => SpecialistFinder(
      rootTitle: 'Where shall we start?',
      rootSubtitle: 'Pick a speciality and start chatting with Nova. You can always switch later.',
      // Open the Nova panel focused on the chosen speciality.
      onPick: (slug) => _closeThenOpenNova(
        ctx,
        () => ref.read(novaUiProvider.notifier).personalize(slug),
      ),
    ),
  );
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How long each boot-splash message holds before the next one takes over.
const kBootMessageStep = Duration(milliseconds: 1200);

/// One complete pass through the four boot-splash messages.
const kBootLoopDuration = Duration(milliseconds: 1200 * 4);

/// Holds the boot splash up until its message sequence has played through at
/// least once. Auth hydration usually finishes well before then, and cutting
/// the sequence off mid-loop reads as a glitch rather than a transition — so
/// the router waits on this as well as on hydration.
final bootGateProvider =
    StateNotifierProvider<BootGateController, bool>((ref) => BootGateController());

class BootGateController extends StateNotifier<bool> {
  BootGateController() : super(false) {
    _timer = Timer(kBootLoopDuration, () {
      // In release mode, mounted check was unreliable. Simply update state
      // unless the timer was cancelled (which disposes the controller).
      state = true;
    });
  }

  late final Timer _timer;

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App-shell UI state — the mobile navigation drawer. Mirrors `uiStore.ts`
/// (`mobileSidebarOpen` / `openMobileSidebar` / `closeMobileSidebar`). Not
/// persisted.
final shellUiProvider =
    StateNotifierProvider<ShellUiController, ShellUiState>((ref) => ShellUiController());

class ShellUiState {
  final bool drawerOpen;
  const ShellUiState({this.drawerOpen = false});
}

class ShellUiController extends StateNotifier<ShellUiState> {
  ShellUiController() : super(const ShellUiState());

  void openDrawer() => state = const ShellUiState(drawerOpen: true);
  void closeDrawer() {
    if (state.drawerOpen) state = const ShellUiState(drawerOpen: false);
  }

  void toggleDrawer() => state = ShellUiState(drawerOpen: !state.drawerOpen);
}

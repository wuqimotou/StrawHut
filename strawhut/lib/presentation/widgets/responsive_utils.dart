import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;

/// Platform-aware responsive utilities for cross-platform UI adaptation.
///
/// These helpers provide consistent platform detection and layout constants
/// for adapting the StrawHut UI between desktop (Windows) and mobile (Android).
///
/// Usage:
/// ```dart
/// if (isMobilePlatform()) {
///   // Use mobile-specific layout
/// }
///
/// final padding = getHorizontalPadding(MediaQuery.sizeOf(context).width);
/// ```

/// Returns true if running on a mobile platform (Android or iOS).
bool isMobilePlatform() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

/// Returns true if running on a desktop platform (Windows, macOS, Linux).
bool isDesktopPlatform() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
}

/// Returns true if running specifically on Android.
bool isAndroid() {
  return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}

/// Returns whether the current platform should use mobile-style dialogs
/// (fullscreen or bottom sheet) instead of desktop AlertDialog.
bool shouldUseMobileDialog() {
  return isMobilePlatform();
}

/// Returns the minimum touch target size in logical pixels for the current platform.
/// - Mobile (Android/iOS): 48dp (Material Design guideline)
/// - Desktop: 40dp (desktop pointer interaction)
double get minTouchTargetSize => isMobilePlatform() ? 48.0 : 40.0;

/// Returns appropriate horizontal padding for the given screen width.
/// On narrow screens (mobile), uses 16dp. On wider screens (desktop), uses 24dp.
double getHorizontalPadding(double screenWidth) {
  if (screenWidth < 600) {
    return 16.0;
  }
  return 24.0;
}

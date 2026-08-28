/// Centralized spacing and radius constants for consistent layouts.
///
/// Usage:
///   padding: EdgeInsets.all(AppSpacing.lg)
///   borderRadius: BorderRadius.circular(AppRadius.md)
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppRadius {
  AppRadius._();

  static const double sm = 8;   // snackbars, chips, small badges
  static const double md = 12;  // inputs, buttons
  static const double lg = 16;  // cards
  static const double xl = 24;  // bottom sheets, dialogs
}

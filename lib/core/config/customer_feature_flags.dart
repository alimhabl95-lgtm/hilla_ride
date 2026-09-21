/// Customer-facing feature toggles (code stays in the repo; UI can be hidden).
class CustomerFeatureFlags {
  CustomerFeatureFlags._();

  /// Marketplace / Stores tab — disabled for first ride-only release.
  static const bool storesTabEnabled = false;
}

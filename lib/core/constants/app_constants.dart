/// Project-wide constants. Business rules live here so they are stated once.
abstract final class AppConstants {
  /// Official application name. Always written in full upper case, never
  /// combined with the word AI.
  static const String appName = 'PIXORA';

  /// Marketing version of this development phase.
  static const String appVersion = '0.1.0';

  /// Android application id.
  static const String applicationId = 'com.pixora.app';

  /// Source repository (used by the About section).
  static const String repositoryUrl = 'https://github.com/saaddanti07/PIXORA';

  /// Largest photo PIXORA will preview on a low-RAM device (40 MB).
  static const int maxImageBytes = 40 * 1024 * 1024;

  /// Largest decoded photo PIXORA will preview (~48 megapixels).
  static const int maxImagePixels = 48 * 1000 * 1000;

  /// Cap for the preview bitmap width, so a 108 MP photo never allocates a
  /// full-resolution texture on a device with 2-3 GB of RAM.
  static const int maxPreviewCacheWidth = 1440;
}

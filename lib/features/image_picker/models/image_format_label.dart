import 'package:pixora/core/utilities/image_format.dart';
import 'package:pixora/l10n/generated/app_localizations.dart';

/// Localized, human readable name for each supported image format.
extension ImageFormatLabel on ImageFormat {
  String label(AppLocalizations l10n) {
    switch (this) {
      case ImageFormat.jpeg:
        return l10n.previewFormatJpeg;
      case ImageFormat.png:
        return l10n.previewFormatPng;
      case ImageFormat.webp:
        return l10n.previewFormatWebp;
      case ImageFormat.gif:
        return l10n.previewFormatGif;
      case ImageFormat.unknown:
        return l10n.previewFormatUnknown;
    }
  }
}

import 'package:pixora/features/image_picker/services/image_selection_controller.dart';
import 'package:pixora/l10n/generated/app_localizations.dart';

/// Maps a selection failure to a localized, actionable message.
String imageSelectionErrorMessage(
  AppLocalizations l10n,
  ImageSelectionErrorKind kind,
) {
  switch (kind) {
    case ImageSelectionErrorKind.permissionDenied:
      return l10n.pickErrorPermission;
    case ImageSelectionErrorKind.pickerUnavailable:
      return l10n.pickErrorUnavailable;
    case ImageSelectionErrorKind.unsupportedFormat:
      return l10n.pickErrorUnsupported;
    case ImageSelectionErrorKind.imageTooLarge:
      return l10n.pickErrorTooLarge;
    case ImageSelectionErrorKind.fileUnreadable:
      return l10n.pickErrorUnreadable;
    case ImageSelectionErrorKind.unknown:
      return l10n.pickErrorUnknown;
  }
}

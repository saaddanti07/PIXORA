/// Failure reasons a photo picker can report.
enum ImagePickerFailure {
  /// The user (or the OS) denied access to photos.
  permissionDenied,

  /// The picked file is not a supported image.
  unsupportedFormat,

  /// No picker activity is available on this device.
  unavailable,

  /// Anything else, including platform channels that are missing in tests.
  unknown,
}

/// Thrown by [ImagePickerService] implementations.
class ImagePickerException implements Exception {
  const ImagePickerException(this.failure, [this.cause]);

  final ImagePickerFailure failure;
  final Object? cause;

  @override
  String toString() => 'ImagePickerException($failure, $cause)';
}

/// Opens the platform photo picker.
///
/// Kept as an interface so the picker can be swapped for a fake in tests, and
/// so a future "camera" or "recent photos" entry point can slot in without
/// touching the UI.
abstract interface class ImagePickerService {
  /// Returns the local path of the chosen image, or `null` when the user
  /// cancels. Throws [ImagePickerException] on failure.
  Future<String?> pickImagePath();
}

import 'dart:io';

import 'package:pixora/core/constants/app_constants.dart';
import 'package:pixora/core/models/image_dimensions.dart';
import 'package:pixora/core/services/image_picker_service.dart';
import 'package:pixora/core/utilities/image_dimensions_reader.dart';
import 'package:pixora/core/utilities/image_format.dart';
import 'package:pixora/features/image_picker/models/picked_image.dart';

/// Why a photo could not be selected.
enum ImageSelectionErrorKind {
  permissionDenied,
  pickerUnavailable,
  unsupportedFormat,
  imageTooLarge,
  fileUnreadable,
  unknown,
}

/// Thrown when a selected photo cannot be used. The UI maps [kind] to a
/// localized message.
class ImageSelectionException implements Exception {
  const ImageSelectionException(this.kind, [this.cause]);

  final ImageSelectionErrorKind kind;
  final Object? cause;

  @override
  String toString() => 'ImageSelectionException($kind, $cause)';
}

/// Turns a picker result into a validated [PickedImage].
///
/// All checks happen on the device: the file must exist, it must really be an
/// image (checked from its signature, not its extension), and it must fit the
/// memory budget PIXORA targets for low-RAM phones.
class ImageSelectionController {
  ImageSelectionController({
    required ImagePickerService picker,
    ImageDimensionsReader reader = const ImageDimensionsReader(),
    int maxBytes = AppConstants.maxImageBytes,
    int maxPixels = AppConstants.maxImagePixels,
  })  : _picker = picker,
        _reader = reader,
        _maxBytes = maxBytes,
        _maxPixels = maxPixels;

  final ImagePickerService _picker;
  final ImageDimensionsReader _reader;
  final int _maxBytes;
  final int _maxPixels;

  /// Opens the picker and validates the result.
  ///
  /// Returns `null` when the user cancels, and throws
  /// [ImageSelectionException] for anything the user needs to know about.
  Future<PickedImage?> pickImage() async {
    final String? path;
    try {
      path = await _picker.pickImagePath();
    } on ImagePickerException catch (error) {
      throw ImageSelectionException(_errorFor(error.failure), error);
    }

    if (path == null) {
      return null;
    }

    try {
      final File file = File(path);
      if (!await file.exists()) {
        throw const ImageSelectionException(ImageSelectionErrorKind.fileUnreadable);
      }
      final int sizeBytes = await file.length();
      if (sizeBytes <= 0) {
        throw const ImageSelectionException(ImageSelectionErrorKind.fileUnreadable);
      }
      if (sizeBytes > _maxBytes) {
        throw const ImageSelectionException(ImageSelectionErrorKind.imageTooLarge);
      }

      final ImageFormat format = await ImageFormatDetector.fromFile(file);
      if (!format.isSupported) {
        throw const ImageSelectionException(ImageSelectionErrorKind.unsupportedFormat);
      }

      final ImageDimensions? dimensions = await _reader.read(file);
      if (dimensions != null && dimensions.pixelCount > _maxPixels) {
        throw const ImageSelectionException(ImageSelectionErrorKind.imageTooLarge);
      }

      return PickedImage(
        path: path,
        fileName: _fileNameOf(path),
        sizeBytes: sizeBytes,
        format: format,
        dimensions: dimensions,
      );
    } on FileSystemException catch (error) {
      throw ImageSelectionException(ImageSelectionErrorKind.fileUnreadable, error);
    }
  }

  static String _fileNameOf(String path) {
    final int index = path.lastIndexOf(Platform.pathSeparator);
    if (index < 0 || index == path.length - 1) {
      return path;
    }
    return path.substring(index + 1);
  }

  static ImageSelectionErrorKind _errorFor(ImagePickerFailure failure) {
    switch (failure) {
      case ImagePickerFailure.permissionDenied:
        return ImageSelectionErrorKind.permissionDenied;
      case ImagePickerFailure.unsupportedFormat:
        return ImageSelectionErrorKind.unsupportedFormat;
      case ImagePickerFailure.unavailable:
        return ImageSelectionErrorKind.pickerUnavailable;
      case ImagePickerFailure.unknown:
        return ImageSelectionErrorKind.unknown;
    }
  }
}

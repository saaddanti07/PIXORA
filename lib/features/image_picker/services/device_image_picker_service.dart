import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pixora/core/services/image_picker_service.dart';

/// Production [ImagePickerService] backed by the Android system photo picker.
///
/// The system picker grants read access to the single photo the user chooses,
/// so PIXORA needs no storage permission at all.
class DeviceImagePickerService implements ImagePickerService {
  DeviceImagePickerService({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> pickImagePath() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      return pickedFile?.path;
    } on PlatformException catch (error) {
      throw ImagePickerException(_failureForCode(error.code), error);
    } on Exception catch (error) {
      throw ImagePickerException(ImagePickerFailure.unknown, error);
    }
  }

  @override
  Future<String?> retrieveLostImagePath() async {
    final LostDataResponse? lostData = await _retrieveLostData();
    if (lostData == null || lostData.isEmpty) {
      return null;
    }

    final PlatformException? failure = lostData.exception;
    if (failure != null) {
      throw ImagePickerException(_failureForCode(failure.code), failure);
    }

    // `files` is the multi-pick shape; `file` is the single-pick shape. PIXORA
    // only ever picks one photo, but both are checked so a change of picker
    // implementation cannot lose the image.
    final List<XFile>? files = lostData.files;
    if (files != null && files.isNotEmpty) {
      return files.first.path;
    }
    return lostData.file?.path;
  }

  Future<LostDataResponse?> _retrieveLostData() async {
    try {
      return await _picker.retrieveLostData();
    } on PlatformException catch (error) {
      throw ImagePickerException(_failureForCode(error.code), error);
    } on Exception catch (error) {
      throw ImagePickerException(ImagePickerFailure.unknown, error);
    }
  }

  static ImagePickerFailure _failureForCode(String code) {
    switch (code) {
      case 'photo_access_denied':
      case 'camera_access_denied':
        return ImagePickerFailure.permissionDenied;
      case 'invalid_image':
      case 'unsupported_format':
      case 'invalid_source':
        return ImagePickerFailure.unsupportedFormat;
      case 'no_available_camera':
      case 'no_available_gallery':
        return ImagePickerFailure.unavailable;
      default:
        return ImagePickerFailure.unknown;
    }
  }
}

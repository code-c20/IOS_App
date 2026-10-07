import 'dart:io';

import 'package:image_picker/image_picker.dart';

class AvatarHelper {
  static Future<File?> pickAvatarImage() async {
    final picker = ImagePicker();

    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1080,
      maxHeight: 1080,
    );

    if (pickedFile == null) return null;
    return File(pickedFile.path);
  }
}

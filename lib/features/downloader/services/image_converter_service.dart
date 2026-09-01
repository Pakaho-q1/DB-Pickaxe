import 'dart:io';
import 'package:image/image.dart' as img;
import '../../../../core/constants/app_constants.dart';

class ImageConverterService {
  static Future<File> convertImage({
    required File inputFile,
    required ImageTargetFormat targetFormat,
  }) async {
    if (targetFormat == ImageTargetFormat.original) {
      return inputFile;
    }

    final bytes = await inputFile.readAsBytes();
    final decodedImage = img.decodeImage(bytes);

    if (decodedImage == null) {
      // Failed to decode, return original
      return inputFile;
    }

    final basePath = inputFile.path.substring(0, inputFile.path.lastIndexOf('.'));
    List<int> outputBytes;
    String newPath;

    switch (targetFormat) {
      case ImageTargetFormat.jpg:
        outputBytes = img.encodeJpg(decodedImage, quality: 90);
        newPath = '$basePath.jpg';
        break;
      case ImageTargetFormat.png:
        outputBytes = img.encodePng(decodedImage);
        newPath = '$basePath.png';
        break;
      case ImageTargetFormat.webp:
        outputBytes = img.encodePng(decodedImage); // fallback or webp
        newPath = '$basePath.png';
        break;
      case ImageTargetFormat.original:
        return inputFile;
    }

    final outputFile = File(newPath);
    await outputFile.writeAsBytes(outputBytes);

    // If new path is different from original path, delete old file
    if (inputFile.path != outputFile.path) {
      try {
        await inputFile.delete();
      } catch (_) {}
    }

    return outputFile;
  }
}

import 'dart:io';
import 'package:archive/archive.dart';

class PackArchiveService {
  /// Packs a list of files into a standard ZIP archive
  static Future<File> packToZip({
    required List<File> files,
    required String outputPath,
  }) async {
    final archive = Archive();

    for (final file in files) {
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final filename = file.path.split(Platform.isWindows ? r'\' : '/').last;
        archive.addFile(ArchiveFile(filename, bytes.length, bytes));
      }
    }

    final encoder = ZipEncoder();
    final zipData = encoder.encode(archive);

    final outFile = File(outputPath);
    if (!await outFile.parent.exists()) {
      await outFile.parent.create(recursive: true);
    }
    await outFile.writeAsBytes(zipData);
    return outFile;
  }

  /// Packs a list of comic/manga images into a CBZ (Comic Book Archive)
  static Future<File> packToCbz({
    required List<File> files,
    required String outputPath,
  }) async {
    final archive = Archive();
    final sortedFiles = List<File>.from(files)
      ..sort((a, b) => a.path.compareTo(b.path));

    for (int i = 0; i < sortedFiles.length; i++) {
      final file = sortedFiles[i];
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final ext = file.path.split('.').last;
        final pageName = 'page_${(i + 1).toString().padLeft(4, '0')}.$ext';
        archive.addFile(ArchiveFile(pageName, bytes.length, bytes));
      }
    }

    final encoder = ZipEncoder();
    final zipData = encoder.encode(archive);

    String finalPath = outputPath;
    if (!finalPath.toLowerCase().endsWith('.cbz')) {
      finalPath = '${finalPath.replaceAll(RegExp(r'\.zip$', caseSensitive: false), '')}.cbz';
    }

    final outFile = File(finalPath);
    if (!await outFile.parent.exists()) {
      await outFile.parent.create(recursive: true);
    }
    await outFile.writeAsBytes(zipData);
    return outFile;
  }
}

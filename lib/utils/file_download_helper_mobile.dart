import 'dart:io';
import 'package:file_picker/file_picker.dart';

class FileDownloadHelper {
  static Future<void> downloadTextFile({
    required String fileName,
    required String content,
  }) async {
    // Mobile simulation / logging.
    print("Mobile download requested for: $fileName");
  }

  static Future<void> downloadBinaryFile({
    required String fileName,
    required List<int> bytes,
  }) async {
    try {
      final String? path = await FilePicker.saveFile(
        dialogTitle: 'Şablonu Kaydet',
        fileName: fileName,
        type: FileType.any,
      );
      if (path != null) {
        final file = File(path);
        await file.writeAsBytes(bytes);
      }
    } catch (e) {
      print("Error saving file: $e");
      try {
        final dir = Directory.systemTemp;
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        print("Fallback: saved to temporary path: ${file.path}");
      } catch (_) {}
    }
  }
}

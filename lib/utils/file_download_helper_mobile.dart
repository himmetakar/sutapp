import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileDownloadHelper {
  static Future<void> downloadTextFile({
    required String fileName,
    required String content,
  }) async {
    try {
      final dir = await _getDownloadDir();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(content);
      print('Dosya kaydedildi: ${file.path}');
    } catch (e) {
      print('downloadTextFile hatası: $e');
    }
  }

  static Future<String?> downloadBinaryFile({
    required String fileName,
    required List<int> bytes,
  }) async {
    try {
      final dir = await _getDownloadDir();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      print('downloadBinaryFile hatası: $e');
      return null;
    }
  }

  static Future<Directory> _getDownloadDir() async {
    if (Platform.isAndroid) {
      // /storage/emulated/0/Downloads — no extra permission needed on Android 10+
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) return dir;
    }
    // Fallback: app documents directory
    return getApplicationDocumentsDirectory();
  }
}

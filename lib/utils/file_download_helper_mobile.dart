import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class FileDownloadHelper {
  static Future<void> downloadTextFile({
    required String fileName,
    required String content,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(content);
      
      // Share file so user can save/share on physical device
      await Share.shareXFiles([XFile(file.path)], text: fileName);
      print('Dosya paylaşıldı: ${file.path}');
    } catch (e) {
      print('downloadTextFile hatası: $e');
    }
  }

  static Future<String?> downloadBinaryFile({
    required String fileName,
    required List<int> bytes,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);
      
      // Share file so user can save/share on physical device
      await Share.shareXFiles([XFile(file.path)], text: fileName);
      return file.path;
    } catch (e) {
      print('downloadBinaryFile hatası: $e');
      return null;
    }
  }
}

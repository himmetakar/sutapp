import 'dart:io';

class FileDownloadHelper {
  static Future<void> downloadTextFile({
    required String fileName,
    required String content,
  }) async {
    // Mobile simulation / logging.
    print("Mobile download requested for: $fileName");
  }
}

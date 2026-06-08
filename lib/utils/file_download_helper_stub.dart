class FileDownloadHelper {
  static Future<void> downloadTextFile({
    required String fileName,
    required String content,
  }) async {
    // Stub implementation: do nothing or print.
    throw UnsupportedError('Cannot download file without platform implementation.');
  }

  static Future<String?> downloadBinaryFile({
    required String fileName,
    required List<int> bytes,
  }) async {
    throw UnsupportedError('Cannot download file without platform implementation.');
  }
}

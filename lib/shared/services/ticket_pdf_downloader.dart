import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:rego/core/storage/secure_storage.dart';

enum TicketPdfDownloadFailure {
  invalidUrl,
  downloadFailed,
  openFailed,
  shareFailed,
}

final class TicketPdfDownloadException implements Exception {
  const TicketPdfDownloadException(this.failure, {this.cause});

  final TicketPdfDownloadFailure failure;
  final Object? cause;

  @override
  String toString() => 'TicketPdfDownloadException($failure, cause: $cause)';
}

typedef TicketPdfFileOpener = Future<OpenResult> Function(String path);
typedef TicketPdfSavePathResolver = Future<String> Function(String bookingRef);
typedef TicketPdfFileSharer = Future<void> Function(
  String path, {
  required String shareSubject,
});

/// Downloads an e-ticket PDF from [invoiceUrl] with auth headers that mirror
/// [dioProvider]'s interceptor so portal URLs work without a browser handoff.
abstract final class TicketPdfDownloader {
  static Future<String> downloadToFile({
    required Dio dio,
    required SecureStorage storage,
    required String localeCode,
    required String invoiceUrl,
    required String bookingRef,
    TicketPdfSavePathResolver? savePathResolver,
  }) async {
    final uri = invoiceUrl.trim().isEmpty ? null : Uri.tryParse(invoiceUrl);
    if (uri == null || !uri.hasScheme) {
      throw const TicketPdfDownloadException(
        TicketPdfDownloadFailure.invalidUrl,
      );
    }

    final savePath = savePathResolver != null
        ? await savePathResolver(bookingRef)
        : await _resolveSavePath(bookingRef);
    final file = File(savePath);
    if (!file.parent.existsSync()) {
      await file.parent.create(recursive: true);
    }

    final headers = await _buildHeaders(storage, localeCode);

    try {
      await dio.download(
        invoiceUrl,
        savePath,
        options: Options(
          headers: headers,
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );
    } on DioException catch (e) {
      throw TicketPdfDownloadException(
        TicketPdfDownloadFailure.downloadFailed,
        cause: e,
      );
    }

    return savePath;
  }

  static Future<void> downloadAndOpen({
    required Dio dio,
    required SecureStorage storage,
    required String localeCode,
    required String invoiceUrl,
    required String bookingRef,
    TicketPdfFileOpener? openFile,
    TicketPdfSavePathResolver? savePathResolver,
  }) async {
    final savePath = await downloadToFile(
      dio: dio,
      storage: storage,
      localeCode: localeCode,
      invoiceUrl: invoiceUrl,
      bookingRef: bookingRef,
      savePathResolver: savePathResolver,
    );

    final opener = openFile ?? OpenFilex.open;
    final result = await opener(savePath);
    if (result.type != ResultType.done) {
      throw TicketPdfDownloadException(
        TicketPdfDownloadFailure.openFailed,
        cause: result.message,
      );
    }
  }

  static Future<void> downloadAndShare({
    required Dio dio,
    required SecureStorage storage,
    required String localeCode,
    required String invoiceUrl,
    required String bookingRef,
    required String shareSubject,
    TicketPdfSavePathResolver? savePathResolver,
    TicketPdfFileSharer? shareFile,
  }) async {
    final savePath = await downloadToFile(
      dio: dio,
      storage: storage,
      localeCode: localeCode,
      invoiceUrl: invoiceUrl,
      bookingRef: bookingRef,
      savePathResolver: savePathResolver,
    );

    try {
      final sharer = shareFile ??
          (String path, {required String shareSubject}) {
            return Share.shareXFiles(
              [XFile(path)],
              subject: shareSubject,
            );
          };
      await sharer(savePath, shareSubject: shareSubject);
    } catch (e) {
      throw TicketPdfDownloadException(
        TicketPdfDownloadFailure.shareFailed,
        cause: e,
      );
    }
  }

  static Future<Map<String, String>> _buildHeaders(
    SecureStorage storage,
    String localeCode,
  ) async {
    final headers = <String, String>{
      'Accept-Language': localeCode,
      'Accept': 'application/pdf',
    };
    final token = await storage.readToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<String> _resolveSavePath(String bookingRef) async {
    final sanitized = bookingRef.replaceAll(RegExp(r'[^\w\-.]'), '_');
    final fileName = 'rego-ticket-$sanitized.pdf';
    Directory directory;
    try {
      final downloads = await getDownloadsDirectory();
      directory = downloads ?? await getApplicationDocumentsDirectory();
    } catch (_) {
      directory = await getApplicationDocumentsDirectory();
    }
    return p.join(directory.path, fileName);
  }
}

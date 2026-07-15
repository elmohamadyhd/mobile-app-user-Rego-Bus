import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import 'package:rego/core/storage/secure_storage.dart';
import 'package:rego/shared/services/ticket_pdf_downloader.dart';

import '../../support/in_memory_secure_storage.dart';

class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return ResponseBody.fromBytes(
      const [0x25, 0x50, 0x44, 0x46],
      200,
      headers: {
        Headers.contentTypeHeader: ['application/pdf'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TicketPdfDownloader', () {
    test('downloads with auth headers and opens the saved file', () async {
      final adapter = _RecordingAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final storage = SecureStorage(
        storage: InMemorySecureStorage({'auth_token': 'test-token'}),
      );
      String? openedPath;

      final tempDir = await Directory.systemTemp.createTemp('rego_ticket_test');

      await TicketPdfDownloader.downloadAndOpen(
        dio: dio,
        storage: storage,
        localeCode: 'ar',
        invoiceUrl: 'https://portal.example.com/orders/1/invoice/download',
        bookingRef: '000001457',
        savePathResolver: (ref) async =>
            p.join(tempDir.path, 'rego-ticket-$ref.pdf'),
        openFile: (path) async {
          openedPath = path;
          return OpenResult(type: ResultType.done);
        },
      );

      expect(adapter.lastOptions?.uri.toString(),
          'https://portal.example.com/orders/1/invoice/download');
      expect(adapter.lastOptions?.headers['Authorization'], 'Bearer test-token');
      expect(adapter.lastOptions?.headers['Accept-Language'], 'ar');
      expect(adapter.lastOptions?.headers['Accept'], 'application/pdf');
      expect(openedPath, isNotNull);
      expect(openedPath!, contains('rego-ticket-000001457.pdf'));
    });

    test('throws invalidUrl when invoiceUrl is empty', () async {
      final dio = Dio()..httpClientAdapter = _RecordingAdapter();

      await expectLater(
        TicketPdfDownloader.downloadAndOpen(
          dio: dio,
          storage: SecureStorage(storage: InMemorySecureStorage({})),
          localeCode: 'en',
          invoiceUrl: '',
          bookingRef: '1',
          openFile: (_) async => OpenResult(type: ResultType.done),
        ),
        throwsA(
          isA<TicketPdfDownloadException>().having(
            (e) => e.failure,
            'failure',
            TicketPdfDownloadFailure.invalidUrl,
          ),
        ),
      );
    });
  });
}

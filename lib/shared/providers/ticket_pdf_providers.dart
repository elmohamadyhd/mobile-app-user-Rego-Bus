import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rego/core/network/dio_client.dart';
import 'package:rego/core/providers/locale_controller.dart';
import 'package:rego/core/storage/secure_storage.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/services/ticket_pdf_downloader.dart';

typedef TicketPdfDownloadFn = Future<void> Function({
  required String invoiceUrl,
  required String bookingRef,
});

typedef TicketPdfShareFn = Future<void> Function({
  required String invoiceUrl,
  required String bookingRef,
  required String shareSubject,
});

final ticketPdfDownloadProvider = Provider<TicketPdfDownloadFn>((ref) {
  final dio = ref.watch(dioProvider);
  final storage = ref.watch(secureStorageProvider);
  final localeCode = ref.watch(localeControllerProvider).languageCode;

  return ({
    required String invoiceUrl,
    required String bookingRef,
  }) {
    return TicketPdfDownloader.downloadAndOpen(
      dio: dio,
      storage: storage,
      localeCode: localeCode,
      invoiceUrl: invoiceUrl,
      bookingRef: bookingRef,
    );
  };
});

final ticketPdfShareProvider = Provider<TicketPdfShareFn>((ref) {
  final dio = ref.watch(dioProvider);
  final storage = ref.watch(secureStorageProvider);
  final localeCode = ref.watch(localeControllerProvider).languageCode;

  return ({
    required String invoiceUrl,
    required String bookingRef,
    required String shareSubject,
  }) {
    return TicketPdfDownloader.downloadAndShare(
      dio: dio,
      storage: storage,
      localeCode: localeCode,
      invoiceUrl: invoiceUrl,
      bookingRef: bookingRef,
      shareSubject: shareSubject,
    );
  };
});

String _ticketPdfErrorMessage(
  AppLocalizations l10n,
  TicketPdfDownloadFailure failure,
) {
  return switch (failure) {
    TicketPdfDownloadFailure.invalidUrl => l10n.eTicketDownloadUnavailable,
    TicketPdfDownloadFailure.downloadFailed ||
    TicketPdfDownloadFailure.openFailed ||
    TicketPdfDownloadFailure.shareFailed =>
      l10n.eTicketDownloadFailed,
  };
}

Future<void> downloadTicketPdf(
  WidgetRef ref,
  BuildContext context, {
  required String invoiceUrl,
  required String bookingRef,
}) async {
  final l10n = AppLocalizations.of(context);
  try {
    await ref.read(ticketPdfDownloadProvider)(
      invoiceUrl: invoiceUrl,
      bookingRef: bookingRef,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.eTicketDownloadSuccess)));
  } on TicketPdfDownloadException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(_ticketPdfErrorMessage(l10n, e.failure))),
      );
  }
}

Future<void> shareTicketPdf(
  WidgetRef ref,
  BuildContext context, {
  required String invoiceUrl,
  required String bookingRef,
}) async {
  final l10n = AppLocalizations.of(context);
  try {
    await ref.read(ticketPdfShareProvider)(
      invoiceUrl: invoiceUrl,
      bookingRef: bookingRef,
      shareSubject: l10n.eTicketShareSubject(bookingRef),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.eTicketShareSuccess)));
  } on TicketPdfDownloadException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(_ticketPdfErrorMessage(l10n, e.failure))),
      );
  }
}

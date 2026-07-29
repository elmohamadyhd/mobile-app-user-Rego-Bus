import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_notification.freezed.dart';

@freezed
abstract class AppNotification with _$AppNotification {
  const AppNotification._();

  const factory AppNotification({
    required String id,
    required String title,
    required String description,
    required String createdDate,
    required String formattedDate,
    @Default(<String, dynamic>{}) Map<String, dynamic> data,
    DateTime? readAt,
  }) = _AppNotification;

  bool get isUnread => readAt == null;
}

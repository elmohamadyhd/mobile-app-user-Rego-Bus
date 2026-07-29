import 'package:safaria/features/notifications/domain/entities/app_notification.dart';
import 'package:safaria/features/notifications/domain/entities/notifications_page.dart';

abstract final class NotificationsDtoMapper {
  static NotificationsPage pageFromEnvelope(dynamic body) {
    final map = body as Map<String, dynamic>;
    final data = (map['data'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final pagination =
        map['pagination'] as Map<String, dynamic>? ?? const {};
    return NotificationsPage(
      items: data.map(_fromMap).toList(growable: false),
      currentPage: _int(pagination['currentPage'], fallback: 1),
      lastPage: _int(pagination['lastPage'], fallback: 1),
      total: _int(pagination['total'], fallback: data.length),
    );
  }

  static AppNotification _fromMap(Map<String, dynamic> json) {
    final rawData = json['data'];
    final data = rawData is Map<String, dynamic>
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};
    final readAtRaw = json['read_at']?.toString();
    return AppNotification(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      createdDate: json['created_date']?.toString() ?? '',
      formattedDate: json['formatted_date']?.toString() ?? '',
      data: data,
      readAt: readAtRaw == null || readAtRaw.isEmpty
          ? null
          : DateTime.tryParse(readAtRaw),
    );
  }

  static int _int(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }
}

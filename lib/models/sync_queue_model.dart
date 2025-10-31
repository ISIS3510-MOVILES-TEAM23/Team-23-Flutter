import 'package:hive/hive.dart';

part 'sync_queue_model.g.dart';

@HiveType(typeId: 0)
class SyncQueueItem {
  @HiveField(0)
  final String operationId;

  @HiveField(1)
  final String type; // 'profile_update', 'message', 'post_draft', etc.

  @HiveField(2)
  final Map<String, dynamic> payload;

  @HiveField(3)
  final int retryCount;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final DateTime? lastAttemptAt;

  @HiveField(6)
  final String? errorMessage;

  const SyncQueueItem({
    required this.operationId,
    required this.type,
    required this.payload,
    this.retryCount = 0,
    required this.createdAt,
    this.lastAttemptAt,
    this.errorMessage,
  });

  SyncQueueItem copyWith({
    String? operationId,
    String? type,
    Map<String, dynamic>? payload,
    int? retryCount,
    DateTime? createdAt,
    DateTime? lastAttemptAt,
    String? errorMessage,
  }) {
    return SyncQueueItem(
      operationId: operationId ?? this.operationId,
      type: type ?? this.type,
      payload: payload ?? this.payload,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt ?? this.createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'operationId': operationId,
      'type': type,
      'payload': payload,
      'retryCount': retryCount,
      'createdAt': createdAt.toIso8601String(),
      'lastAttemptAt': lastAttemptAt?.toIso8601String(),
      'errorMessage': errorMessage,
    };
  }

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) {
    return SyncQueueItem(
      operationId: json['operationId'],
      type: json['type'],
      payload: Map<String, dynamic>.from(json['payload']),
      retryCount: json['retryCount'] ?? 0,
      createdAt: DateTime.parse(json['createdAt']),
      lastAttemptAt: json['lastAttemptAt'] != null
          ? DateTime.parse(json['lastAttemptAt'])
          : null,
      errorMessage: json['errorMessage'],
    );
  }
}

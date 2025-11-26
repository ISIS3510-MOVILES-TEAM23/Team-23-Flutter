import 'package:uuid/uuid.dart';

/// Status of a draft feedback
enum DraftFeedbackStatus {
  editing,          // User is actively editing
  pendingUpload,    // Waiting to be uploaded when online
  uploading,        // Currently being uploaded
  failed,           // Upload failed
}

/// Draft feedback model for offline feedback creation
/// Similar to DraftPost but for product reviews/feedback
class DraftFeedback {
  final String draftId;
  final String buyerId;
  final String sellerId;
  final String purchaseId;
  final String comment;
  final int rating; // 1-5 stars
  final List<String> localImagePaths;  // Paths to local cached images
  final DraftFeedbackStatus status;
  final DateTime createdAt;
  final DateTime lastModified;
  final String? errorMessage;  // Error message if upload failed

  DraftFeedback({
    String? draftId,
    required this.buyerId,
    required this.sellerId,
    required this.purchaseId,
    this.comment = '',
    this.rating = 0,
    List<String>? localImagePaths,
    this.status = DraftFeedbackStatus.editing,
    DateTime? createdAt,
    DateTime? lastModified,
    this.errorMessage,
  })  : draftId = draftId ?? const Uuid().v4(),
        localImagePaths = localImagePaths ?? [],
        createdAt = createdAt ?? DateTime.now(),
        lastModified = lastModified ?? DateTime.now();

  /// Create a copy with updated fields
  DraftFeedback copyWith({
    String? draftId,
    String? buyerId,
    String? sellerId,
    String? purchaseId,
    String? comment,
    int? rating,
    List<String>? localImagePaths,
    DraftFeedbackStatus? status,
    DateTime? createdAt,
    DateTime? lastModified,
    String? errorMessage,
  }) {
    return DraftFeedback(
      draftId: draftId ?? this.draftId,
      buyerId: buyerId ?? this.buyerId,
      sellerId: sellerId ?? this.sellerId,
      purchaseId: purchaseId ?? this.purchaseId,
      comment: comment ?? this.comment,
      rating: rating ?? this.rating,
      localImagePaths: localImagePaths ?? this.localImagePaths,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? DateTime.now(),
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Convert to JSON for storage (Hive)
  Map<String, dynamic> toJson() {
    return {
      'draftId': draftId,
      'buyerId': buyerId,
      'sellerId': sellerId,
      'purchaseId': purchaseId,
      'comment': comment,
      'rating': rating,
      'localImagePaths': localImagePaths,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'lastModified': lastModified.toIso8601String(),
      'errorMessage': errorMessage,
    };
  }

  /// Create from JSON (Hive)
  factory DraftFeedback.fromJson(Map<String, dynamic> json) {
    return DraftFeedback(
      draftId: json['draftId'] as String,
      buyerId: json['buyerId'] as String,
      sellerId: json['sellerId'] as String? ?? '',
      purchaseId: json['purchaseId'] as String,
      comment: json['comment'] as String? ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      localImagePaths: (json['localImagePaths'] as List?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      status: _statusFromString(json['status'] as String?),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'] as String)
          : DateTime.now(),
      errorMessage: json['errorMessage'] as String?,
    );
  }

  static DraftFeedbackStatus _statusFromString(String? status) {
    switch (status) {
      case 'editing':
        return DraftFeedbackStatus.editing;
      case 'pendingUpload':
        return DraftFeedbackStatus.pendingUpload;
      case 'uploading':
        return DraftFeedbackStatus.uploading;
      case 'failed':
        return DraftFeedbackStatus.failed;
      default:
        return DraftFeedbackStatus.editing;
    }
  }

  /// Check if draft has content
  bool get hasContent {
    return comment.isNotEmpty || 
           rating > 0 || 
           localImagePaths.isNotEmpty;
  }

  /// Check if draft is ready to be uploaded
  bool get isValid {
    return buyerId.isNotEmpty &&
           sellerId.isNotEmpty &&
           purchaseId.isNotEmpty &&
           comment.trim().isNotEmpty &&
           rating > 0 &&
           rating <= 5;
  }
}


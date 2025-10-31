import 'package:uuid/uuid.dart';

/// Status of a draft post
enum DraftStatus {
  editing,          // User is actively editing
  pendingUpload,    // Waiting to be uploaded when online
  uploading,        // Currently being uploaded
  failed,           // Upload failed
}

/// Draft post model for offline post creation (Scenario 8)
class DraftPost {
  final String draftId;
  final String userId;
  final String title;
  final String description;
  final double price;
  final String? categoryId;
  final String? categoryName;
  final List<String> localImagePaths;  // Paths to local cached images
  final DraftStatus status;
  final DateTime createdAt;
  final DateTime lastModified;
  final String? errorMessage;  // Error message if upload failed
  final double? latitude;  // Location data (optional)
  final double? longitude; // Location data (optional)

  DraftPost({
    String? draftId,
    required this.userId,
    this.title = '',
    this.description = '',
    this.price = 0.0,
    this.categoryId,
    this.categoryName,
    List<String>? localImagePaths,
    this.status = DraftStatus.editing,
    DateTime? createdAt,
    DateTime? lastModified,
    this.errorMessage,
    this.latitude,
    this.longitude,
  })  : draftId = draftId ?? const Uuid().v4(),
        localImagePaths = localImagePaths ?? [],
        createdAt = createdAt ?? DateTime.now(),
        lastModified = lastModified ?? DateTime.now();

  /// Create a copy with updated fields
  DraftPost copyWith({
    String? draftId,
    String? userId,
    String? title,
    String? description,
    double? price,
    String? categoryId,
    String? categoryName,
    List<String>? localImagePaths,
    DraftStatus? status,
    DateTime? createdAt,
    DateTime? lastModified,
    String? errorMessage,
    double? latitude,
    double? longitude,
  }) {
    return DraftPost(
      draftId: draftId ?? this.draftId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      localImagePaths: localImagePaths ?? this.localImagePaths,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? DateTime.now(),
      errorMessage: errorMessage ?? this.errorMessage,
      latitude: latitude == null ? this.latitude : latitude,
      longitude: longitude == null ? this.longitude : longitude,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'draftId': draftId,
      'userId': userId,
      'title': title,
      'description': description,
      'price': price,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'localImagePaths': localImagePaths,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'lastModified': lastModified.toIso8601String(),
      'errorMessage': errorMessage,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  /// Create from JSON
  factory DraftPost.fromJson(Map<String, dynamic> json) {
    return DraftPost(
      draftId: json['draftId'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      categoryId: json['categoryId'] as String?,
      categoryName: json['categoryName'] as String?,
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
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  static DraftStatus _statusFromString(String? status) {
    switch (status) {
      case 'editing':
        return DraftStatus.editing;
      case 'pendingUpload':
        return DraftStatus.pendingUpload;
      case 'uploading':
        return DraftStatus.uploading;
      case 'failed':
        return DraftStatus.failed;
      default:
        return DraftStatus.editing;
    }
  }

  /// Check if draft has content
  bool get hasContent {
    return title.isNotEmpty || 
           description.isNotEmpty || 
           price > 0 || 
           localImagePaths.isNotEmpty;
  }

  /// Check if draft is ready to be saved
  bool get isValid {
    return title.trim().isNotEmpty &&
           description.trim().isNotEmpty &&
           price > 0 &&
           categoryId != null &&
           localImagePaths.isNotEmpty;
  }
}


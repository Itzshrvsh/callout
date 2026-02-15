enum JoinRequestStatus { pending, approved, rejected }

class JoinRequestModel {
  final String id;
  final String organizationId;
  final String userId;
  final JoinRequestStatus status;
  final String? message;
  final DateTime createdAt;
  final DateTime? processedAt;
  final String? processedBy;

  // Additional info (from joins)
  final String? userEmail;
  final String? userName;
  final String? userAvatarUrl;
  final String? organizationName;

  JoinRequestModel({
    required this.id,
    required this.organizationId,
    required this.userId,
    required this.status,
    this.message,
    required this.createdAt,
    this.processedAt,
    this.processedBy,
    this.userEmail,
    this.userName,
    this.userAvatarUrl,
    this.organizationName,
  });

  factory JoinRequestModel.fromJson(Map<String, dynamic> json) {
    return JoinRequestModel(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      userId: json['user_id'] as String,
      status: _parseStatus(json['status'] as String),
      message: json['message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      processedAt: json['processed_at'] != null
          ? DateTime.parse(json['processed_at'] as String)
          : null,
      processedBy: json['processed_by'] as String?,
      userEmail: json['user_email'] as String?,
      userName: json['user_name'] as String?,
      userAvatarUrl: json['user_avatar_url'] as String?,
      organizationName: json['organization_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'user_id': userId,
      'status': status.name,
      'message': message,
      'created_at': createdAt.toIso8601String(),
      'processed_at': processedAt?.toIso8601String(),
      'processed_by': processedBy,
    };
  }

  static JoinRequestStatus _parseStatus(String status) {
    switch (status) {
      case 'pending':
        return JoinRequestStatus.pending;
      case 'approved':
        return JoinRequestStatus.approved;
      case 'rejected':
        return JoinRequestStatus.rejected;
      default:
        return JoinRequestStatus.pending;
    }
  }

  String getStatusDisplayName() {
    switch (status) {
      case JoinRequestStatus.pending:
        return 'Pending';
      case JoinRequestStatus.approved:
        return 'Approved';
      case JoinRequestStatus.rejected:
        return 'Rejected';
    }
  }
}

enum ImportanceLevel { low, medium, high, critical }

enum RequestStatus { pending, approved, rejected, escalated }

class RequestModel {
  final String id;
  final String organizationId;
  final String createdBy;
  final String requestType;
  final String title;
  final String description;
  final ImportanceLevel importanceLevel;
  final RequestStatus status;
  final String? currentApproverId;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Additional creator info (from join)
  final String? creatorName;
  final String? creatorEmail;
  final String? creatorRole;

  RequestModel({
    required this.id,
    required this.organizationId,
    required this.createdBy,
    required this.requestType,
    required this.title,
    required this.description,
    required this.importanceLevel,
    required this.status,
    this.currentApproverId,
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
    this.creatorName,
    this.creatorEmail,
    this.creatorRole,
  });

  factory RequestModel.fromJson(Map<String, dynamic> json) {
    return RequestModel(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      createdBy: json['created_by'] as String,
      requestType: json['request_type'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      importanceLevel: _parseImportance(json['importance_level'] as String),
      status: _parseStatus(json['status'] as String),
      currentApproverId: json['current_approver_id'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      creatorName: json['creator_name'] as String?,
      creatorEmail: json['creator_email'] as String?,
      creatorRole: json['creator_role'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'created_by': createdBy,
      'request_type': requestType,
      'title': title,
      'description': description,
      'importance_level': importanceLevel.name,
      'status': status.name,
      'current_approver_id': currentApproverId,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static ImportanceLevel _parseImportance(String importance) {
    switch (importance) {
      case 'low':
        return ImportanceLevel.low;
      case 'medium':
        return ImportanceLevel.medium;
      case 'high':
        return ImportanceLevel.high;
      case 'critical':
        return ImportanceLevel.critical;
      default:
        return ImportanceLevel.medium;
    }
  }

  static RequestStatus _parseStatus(String status) {
    switch (status) {
      case 'pending':
        return RequestStatus.pending;
      case 'approved':
        return RequestStatus.approved;
      case 'rejected':
        return RequestStatus.rejected;
      case 'escalated':
        return RequestStatus.escalated;
      default:
        return RequestStatus.pending;
    }
  }

  String getImportanceDisplayName() {
    switch (importanceLevel) {
      case ImportanceLevel.low:
        return 'Low';
      case ImportanceLevel.medium:
        return 'Medium';
      case ImportanceLevel.high:
        return 'High';
      case ImportanceLevel.critical:
        return 'Critical';
    }
  }

  String getStatusDisplayName() {
    switch (status) {
      case RequestStatus.pending:
        return 'Pending';
      case RequestStatus.approved:
        return 'Approved';
      case RequestStatus.rejected:
        return 'Rejected';
      case RequestStatus.escalated:
        return 'Escalated';
    }
  }

  RequestModel copyWith({
    String? id,
    String? organizationId,
    String? createdBy,
    String? requestType,
    String? title,
    String? description,
    ImportanceLevel? importanceLevel,
    RequestStatus? status,
    String? currentApproverId,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? creatorName,
    String? creatorEmail,
    String? creatorRole,
  }) {
    return RequestModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      createdBy: createdBy ?? this.createdBy,
      requestType: requestType ?? this.requestType,
      title: title ?? this.title,
      description: description ?? this.description,
      importanceLevel: importanceLevel ?? this.importanceLevel,
      status: status ?? this.status,
      currentApproverId: currentApproverId ?? this.currentApproverId,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      creatorName: creatorName ?? this.creatorName,
      creatorEmail: creatorEmail ?? this.creatorEmail,
      creatorRole: creatorRole ?? this.creatorRole,
    );
  }
}

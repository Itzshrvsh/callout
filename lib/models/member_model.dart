enum MemberRole { admin, ceo, manager, teamLeader, member }

enum MemberStatus { pending, active, inactive }

class MemberModel {
  final String id;
  final String organizationId;
  final String userId;
  final MemberRole role;
  final MemberStatus status;
  final String? department;
  final String? reportsTo;
  final DateTime joinedAt;

  // Additional user info (from join with users table)
  final String? email;
  final String? fullName;
  final String? avatarUrl;

  MemberModel({
    required this.id,
    required this.organizationId,
    required this.userId,
    required this.role,
    required this.status,
    this.department,
    this.reportsTo,
    required this.joinedAt,
    this.email,
    this.fullName,
    this.avatarUrl,
  });

  factory MemberModel.fromJson(Map<String, dynamic> json) {
    return MemberModel(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      userId: json['user_id'] as String,
      role: _parseRole(json['role'] as String),
      status: _parseStatus(json['status'] as String),
      department: json['department'] as String?,
      reportsTo: json['reports_to'] as String?,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      email: json['email'] as String?,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'user_id': userId,
      'role': role.name,
      'status': status.name,
      'department': department,
      'reports_to': reportsTo,
      'joined_at': joinedAt.toIso8601String(),
    };
  }

  static MemberRole _parseRole(String role) {
    switch (role) {
      case 'admin':
        return MemberRole.admin;
      case 'ceo':
        return MemberRole.ceo;
      case 'manager':
        return MemberRole.manager;
      case 'team_leader':
        return MemberRole.teamLeader;
      case 'member':
      default:
        return MemberRole.member;
    }
  }

  static MemberStatus _parseStatus(String status) {
    switch (status) {
      case 'pending':
        return MemberStatus.pending;
      case 'active':
        return MemberStatus.active;
      case 'inactive':
        return MemberStatus.inactive;
      default:
        return MemberStatus.pending;
    }
  }

  String getRoleDisplayName() {
    switch (role) {
      case MemberRole.admin:
        return 'Admin';
      case MemberRole.ceo:
        return 'CEO';
      case MemberRole.manager:
        return 'Manager';
      case MemberRole.teamLeader:
        return 'Team Leader';
      case MemberRole.member:
        return 'Member';
    }
  }

  MemberModel copyWith({
    String? id,
    String? organizationId,
    String? userId,
    MemberRole? role,
    MemberStatus? status,
    String? department,
    String? reportsTo,
    DateTime? joinedAt,
    String? email,
    String? fullName,
    String? avatarUrl,
  }) {
    return MemberModel(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      status: status ?? this.status,
      department: department ?? this.department,
      reportsTo: reportsTo ?? this.reportsTo,
      joinedAt: joinedAt ?? this.joinedAt,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

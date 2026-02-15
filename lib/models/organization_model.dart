class OrganizationModel {
  final String id;
  final String name;
  final String? description;
  final String adminId;
  final Map<String, dynamic> settings;
  final DateTime createdAt;

  OrganizationModel({
    required this.id,
    required this.name,
    this.description,
    required this.adminId,
    this.settings = const {},
    required this.createdAt,
  });

  factory OrganizationModel.fromJson(Map<String, dynamic> json) {
    return OrganizationModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      adminId: json['admin_id'] as String,
      settings: json['settings'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'admin_id': adminId,
      'settings': settings,
      'created_at': createdAt.toIso8601String(),
    };
  }

  OrganizationModel copyWith({
    String? id,
    String? name,
    String? description,
    String? adminId,
    Map<String, dynamic>? settings,
    DateTime? createdAt,
  }) {
    return OrganizationModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      adminId: adminId ?? this.adminId,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/organization_model.dart';
import '../models/member_model.dart';
import '../models/join_request_model.dart';

class OrganizationService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  // Create a new organization
  Future<OrganizationModel> createOrganization({
    required String name,
    String? description,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('organizations')
          .insert({
            'name': name,
            'description': description,
            'admin_id': userId,
          })
          .select()
          .single();

      // Also create member entry for admin
      await _supabase.from('organization_members').insert({
        'organization_id': response['id'],
        'user_id': userId,
        'role': 'admin',
        'status': 'active',
      });

      return OrganizationModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create organization: ${e.toString()}');
    }
  }

  // Get user's organizations
  Future<List<OrganizationModel>> getUserOrganizations() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('organization_members')
          .select('organization_id, organizations(*)')
          .eq('user_id', userId)
          .eq('status', 'active');

      return (response as List)
          .map(
            (item) => OrganizationModel.fromJson(
              item['organizations'] as Map<String, dynamic>,
            ),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch organizations: ${e.toString()}');
    }
  }

  // Search organizations by name
  Future<List<OrganizationModel>> searchOrganizations(String query) async {
    try {
      final response = await _supabase
          .from('organizations')
          .select()
          .ilike('name', '%$query%')
          .limit(20);

      return (response as List)
          .map((item) => OrganizationModel.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Failed to search organizations: ${e.toString()}');
    }
  }

  // Request to join an organization
  Future<JoinRequestModel> requestToJoin({
    required String organizationId,
    String? message,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('join_requests')
          .insert({
            'organization_id': organizationId,
            'user_id': userId,
            'message': message,
            'status': 'pending',
          })
          .select()
          .single();

      return JoinRequestModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create join request: ${e.toString()}');
    }
  }

  // Get pending join requests for an organization (admin only)
  Future<List<JoinRequestModel>> getPendingJoinRequests(
    String organizationId,
  ) async {
    try {
      final response = await _supabase
          .from('join_requests')
          .select('''
            *,
            user_email:users!join_requests_user_id_fkey(email),
            user_name:users!join_requests_user_id_fkey(full_name),
            user_avatar_url:users!join_requests_user_id_fkey(avatar_url)
          ''')
          .eq('organization_id', organizationId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return (response as List).map((item) {
        final flattenedItem = <String, dynamic>{
          ...item,
          'user_email': item['user_email']?['email'],
          'user_name': item['user_name']?['full_name'],
          'user_avatar_url': item['user_avatar_url']?['avatar_url'],
        };
        return JoinRequestModel.fromJson(flattenedItem);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch join requests: ${e.toString()}');
    }
  }

  // Approve join request
  Future<void> approveJoinRequest({
    required String requestId,
    required String organizationId,
    required String userId,
    required MemberRole role,
    String? department,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('User not authenticated');

      // Update join request status
      await _supabase
          .from('join_requests')
          .update({
            'status': 'approved',
            'processed_at': DateTime.now().toIso8601String(),
            'processed_by': currentUserId,
          })
          .eq('id', requestId);

      // Create organization member entry
      await _supabase.from('organization_members').insert({
        'organization_id': organizationId,
        'user_id': userId,
        'role': role.name
            .replaceAll(RegExp(r'([A-Z])'), '_\$1')
            .toLowerCase()
            .substring(1),
        'status': 'active',
        'department': department,
      });
    } catch (e) {
      throw Exception('Failed to approve join request: ${e.toString()}');
    }
  }

  // Reject join request
  Future<void> rejectJoinRequest(String requestId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('User not authenticated');

      await _supabase
          .from('join_requests')
          .update({
            'status': 'rejected',
            'processed_at': DateTime.now().toIso8601String(),
            'processed_by': currentUserId,
          })
          .eq('id', requestId);
    } catch (e) {
      throw Exception('Failed to reject join request: ${e.toString()}');
    }
  }

  // Get organization members
  Future<List<MemberModel>> getOrganizationMembers(
    String organizationId,
  ) async {
    try {
      final response = await _supabase
          .from('organization_members')
          .select('''
            *,
            email:users!organization_members_user_id_fkey(email),
            full_name:users!organization_members_user_id_fkey(full_name),
            avatar_url:users!organization_members_user_id_fkey(avatar_url)
          ''')
          .eq('organization_id', organizationId)
          .eq('status', 'active')
          .order('role');

      return (response as List).map((item) {
        final flattenedItem = <String, dynamic>{
          ...item,
          'email': item['email']?['email'],
          'full_name': item['full_name']?['full_name'],
          'avatar_url': item['avatar_url']?['avatar_url'],
        };
        return MemberModel.fromJson(flattenedItem);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch members: ${e.toString()}');
    }
  }

  // Update member role
  Future<void> updateMemberRole({
    required String memberId,
    required MemberRole role,
    String? department,
    String? reportsTo,
  }) async {
    try {
      final updates = <String, dynamic>{
        'role': role.name
            .replaceAll(RegExp(r'([A-Z])'), '_\$1')
            .toLowerCase()
            .substring(1),
      };

      if (department != null) updates['department'] = department;
      if (reportsTo != null) updates['reports_to'] = reportsTo;

      await _supabase
          .from('organization_members')
          .update(updates)
          .eq('id', memberId);
    } catch (e) {
      throw Exception('Failed to update member role: ${e.toString()}');
    }
  }

  // Remove member from organization
  Future<void> removeMember(String memberId) async {
    try {
      await _supabase
          .from('organization_members')
          .update({'status': 'inactive'})
          .eq('id', memberId);
    } catch (e) {
      throw Exception('Failed to remove member: ${e.toString()}');
    }
  }
}

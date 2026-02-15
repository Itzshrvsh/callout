import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/request_model.dart';
import 'llm_service.dart';

class RequestService {
  final SupabaseClient _supabase = SupabaseConfig.client;
  final LLMService _llmService = LLMService();

  // Create a new request with LLM classification
  Future<RequestModel> createRequest({
    required String organizationId,
    required String memberId,
    required String title,
    required String description,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    try {
      // Classify request using LLM
      final classification = await _llmService.classifyRequest(
        title: title,
        description: description,
      );

      // Merge metadata
      final metadata = {
        ...classification.extractedMetadata,
        if (additionalMetadata != null) ...additionalMetadata,
        'llm_reasoning': classification.reasoning,
      };

      // Determine initial approver
      final approverId = await _determineInitialApprover(memberId);

      // Create request
      final response = await _supabase
          .from('requests')
          .insert({
            'organization_id': organizationId,
            'created_by': memberId,
            'request_type': classification.requestType,
            'title': title,
            'description': description,
            'importance_level': classification.importanceLevel.name,
            'status': 'pending',
            'current_approver_id': approverId,
            'metadata': metadata,
          })
          .select()
          .single();

      return RequestModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create request: ${e.toString()}');
    }
  }

  // Get user's submitted requests
  Future<List<RequestModel>> getMyRequests(String memberId) async {
    try {
      final response = await _supabase
          .from('requests')
          .select('''
            *,
            creator_name:organization_members!requests_created_by_fkey(
              users!organization_members_user_id_fkey(full_name)
            )
          ''')
          .eq('created_by', memberId)
          .order('created_at', ascending: false);

      return (response as List).map((item) {
        final flattenedItem = <String, dynamic>{
          ...item,
          'creator_name': item['creator_name']?['users']?['full_name'],
        };
        return RequestModel.fromJson(flattenedItem);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch requests: ${e.toString()}');
    }
  }

  // Get requests pending user's approval
  Future<List<RequestModel>> getPendingApprovals(String memberId) async {
    try {
      final response = await _supabase
          .from('requests')
          .select('''
            *,
            creator_name:organization_members!requests_created_by_fkey(
              users!organization_members_user_id_fkey(full_name)
            ),
            creator_email:organization_members!requests_created_by_fkey(
              users!organization_members_user_id_fkey(email)
            ),
            creator_role:organization_members!requests_created_by_fkey(role)
          ''')
          .eq('current_approver_id', memberId)
          .eq('status', 'pending')
          .order('importance_level', ascending: false)
          .order('created_at', ascending: true);

      return (response as List).map((item) {
        final flattenedItem = <String, dynamic>{
          ...item,
          'creator_name': item['creator_name']?['users']?['full_name'],
          'creator_email': item['creator_email']?['users']?['email'],
          'creator_role': item['creator_role']?['role'],
        };
        return RequestModel.fromJson(flattenedItem);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch pending approvals: ${e.toString()}');
    }
  }

  // Get all requests for an organization
  Future<List<RequestModel>> getOrganizationRequests(
    String organizationId,
  ) async {
    try {
      final response = await _supabase
          .from('requests')
          .select('''
            *,
            creator_name:organization_members!requests_created_by_fkey(
              users!organization_members_user_id_fkey(full_name)
            )
          ''')
          .eq('organization_id', organizationId)
          .order('created_at', ascending: false)
          .limit(100);

      return (response as List).map((item) {
        final flattenedItem = <String, dynamic>{
          ...item,
          'creator_name': item['creator_name']?['users']?['full_name'],
        };
        return RequestModel.fromJson(flattenedItem);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch organization requests: ${e.toString()}');
    }
  }

  // Approve a request
  Future<void> approveRequest({
    required String requestId,
    required String approverId,
    String? comments,
  }) async {
    try {
      // Create approval record
      await _supabase.from('request_approvals').insert({
        'request_id': requestId,
        'approver_id': approverId,
        'action': 'approved',
        'comments': comments,
      });

      // Update request status
      await _supabase
          .from('requests')
          .update({'status': 'approved', 'current_approver_id': null})
          .eq('id', requestId);
    } catch (e) {
      throw Exception('Failed to approve request: ${e.toString()}');
    }
  }

  // Reject a request
  Future<void> rejectRequest({
    required String requestId,
    required String approverId,
    String? comments,
  }) async {
    try {
      // Create approval record
      await _supabase.from('request_approvals').insert({
        'request_id': requestId,
        'approver_id': approverId,
        'action': 'rejected',
        'comments': comments,
      });

      // Update request status
      await _supabase
          .from('requests')
          .update({'status': 'rejected', 'current_approver_id': null})
          .eq('id', requestId);
    } catch (e) {
      throw Exception('Failed to reject request: ${e.toString()}');
    }
  }

  // Escalate a request to the next approver
  Future<void> escalateRequest({
    required String requestId,
    required String currentApproverId,
    String? reason,
  }) async {
    try {
      // Create approval record for escalation
      await _supabase.from('request_approvals').insert({
        'request_id': requestId,
        'approver_id': currentApproverId,
        'action': 'escalated',
        'comments': reason,
      });

      // Use database function to determine next approver
      final nextApprover = await _supabase.rpc(
        'assign_next_approver',
        params: {
          'p_request_id': requestId,
          'p_current_approver_id': currentApproverId,
        },
      );

      // Update request
      await _supabase
          .from('requests')
          .update({'status': 'escalated', 'current_approver_id': nextApprover})
          .eq('id', requestId);
    } catch (e) {
      throw Exception('Failed to escalate request: ${e.toString()}');
    }
  }

  // Get request details by ID
  Future<RequestModel> getRequestById(String requestId) async {
    try {
      final response = await _supabase
          .from('requests')
          .select('''
            *,
            creator_name:organization_members!requests_created_by_fkey(
              users!organization_members_user_id_fkey(full_name)
            ),
            creator_email:organization_members!requests_created_by_fkey(
              users!organization_members_user_id_fkey(email)
            ),
            creator_role:organization_members!requests_created_by_fkey(role)
          ''')
          .eq('id', requestId)
          .single();

      final flattenedItem = <String, dynamic>{
        ...response,
        'creator_name': response['creator_name']?['users']?['full_name'],
        'creator_email': response['creator_email']?['users']?['email'],
        'creator_role': response['creator_role']?['role'],
      };

      return RequestModel.fromJson(flattenedItem);
    } catch (e) {
      throw Exception('Failed to fetch request: ${e.toString()}');
    }
  }

  // Private helper to determine initial approver based on creator's hierarchy
  Future<String?> _determineInitialApprover(String creatorMemberId) async {
    try {
      // Get creator's reports_to
      final creator = await _supabase
          .from('organization_members')
          .select('reports_to')
          .eq('id', creatorMemberId)
          .single();

      return creator['reports_to'] as String?;
    } catch (e) {
      debugPrint('Could not determine initial approver: $e');
      return null;
    }
  }
}

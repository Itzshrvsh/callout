import 'package:flutter/material.dart';
import '../../models/member_model.dart';
import '../../models/join_request_model.dart';
import '../../services/organization_service.dart';

class ManageMembersScreen extends StatefulWidget {
  final String organizationId;

  const ManageMembersScreen({super.key, required this.organizationId});

  @override
  State<ManageMembersScreen> createState() => _ManageMembersScreenState();
}

class _ManageMembersScreenState extends State<ManageMembersScreen>
    with SingleTickerProviderStateMixin {
  final OrganizationService _orgService = OrganizationService();
  late TabController _tabController;
  List<MemberModel> _members = [];
  List<JoinRequestModel> _joinRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final members = await _orgService.getOrganizationMembers(
        widget.organizationId,
      );
      final requests = await _orgService.getPendingJoinRequests(
        widget.organizationId,
      );

      setState(() {
        _members = members;
        _joinRequests = requests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  Future<void> _approveJoinRequest(JoinRequestModel request) async {
    // Show role selection dialog
    final role = await showDialog<MemberRole>(
      context: context,
      builder: (context) => _RoleSelectionDialog(),
    );

    if (role == null) return;

    try {
      await _orgService.approveJoinRequest(
        requestId: request.id,
        organizationId: widget.organizationId,
        userId: request.userId,
        role: role,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Join request approved!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectJoinRequest(JoinRequestModel request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Request'),
        content: Text(
          'Are you sure you want to reject ${request.userName ?? request.userEmail}\'s request?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _orgService.rejectJoinRequest(request.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Request rejected')));
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Members'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.people),
              text: 'Members (${_members.length})',
            ),
            Tab(
              icon: const Icon(Icons.pending),
              text: 'Requests (${_joinRequests.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildMembersList(), _buildJoinRequestsList()],
            ),
    );
  }

  Widget _buildMembersList() {
    if (_members.isEmpty) {
      return const Center(child: Text('No members yet'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _members.length,
        itemBuilder: (context, index) {
          final member = _members[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                child: Text(
                  (member.fullName ?? member.email ?? 'U')[0].toUpperCase(),
                ),
              ),
              title: Text(member.fullName ?? 'Unknown'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.email ?? ''),
                  if (member.department != null)
                    Text('Department: ${member.department}'),
                ],
              ),
              trailing: Chip(
                label: Text(member.getRoleDisplayName()),
                backgroundColor: _getRoleColor(member.role),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildJoinRequestsList() {
    if (_joinRequests.isEmpty) {
      return const Center(child: Text('No pending requests'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _joinRequests.length,
        itemBuilder: (context, index) {
          final request = _joinRequests[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        child: Text(
                          (request.userName ?? request.userEmail ?? 'U')[0]
                              .toUpperCase(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.userName ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              request.userEmail ?? '',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (request.message != null &&
                      request.message!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(request.message!),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _rejectJoinRequest(request),
                        child: const Text('Reject'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _approveJoinRequest(request),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Approve'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getRoleColor(MemberRole role) {
    switch (role) {
      case MemberRole.admin:
        return Colors.red.shade100;
      case MemberRole.ceo:
        return Colors.purple.shade100;
      case MemberRole.manager:
        return Colors.blue.shade100;
      case MemberRole.teamLeader:
        return Colors.green.shade100;
      case MemberRole.member:
        return Colors.grey.shade200;
    }
  }
}

class _RoleSelectionDialog extends StatefulWidget {
  @override
  State<_RoleSelectionDialog> createState() => _RoleSelectionDialogState();
}

class _RoleSelectionDialogState extends State<_RoleSelectionDialog> {
  MemberRole _selectedRole = MemberRole.member;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Role'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: MemberRole.values
            .where(
              (role) => role != MemberRole.admin,
            ) // Don't allow selecting admin
            .map((role) {
              return RadioListTile<MemberRole>(
                title: Text(_getRoleDisplayName(role)),
                value: role,
                groupValue: _selectedRole,
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value!;
                  });
                },
              );
            })
            .toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_selectedRole),
          child: const Text('Confirm'),
        ),
      ],
    );
  }

  String _getRoleDisplayName(MemberRole role) {
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
}

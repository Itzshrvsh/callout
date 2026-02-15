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
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {}); // Rebuild to show/hide FAB
      }
    });
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
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: _showAddMemberDialog,
              child: const Icon(Icons.person_add),
            )
          : null,
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
              onTap: () => _showEditMemberSheet(member),
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

  Future<void> _showAddMemberDialog() async {
    final emailController = TextEditingController();
    final departmentController = TextEditingController();
    MemberRole selectedRole = MemberRole.member;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'User Email',
                  hintText: 'Enter email address',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<MemberRole>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: 'Role'),
                items: MemberRole.values
                    .where((r) => r != MemberRole.admin)
                    .map((role) {
                      return DropdownMenuItem(
                        value: role,
                        child: Text(
                          _RoleSelectionDialogState.getRoleDisplayName(role),
                        ),
                      );
                    })
                    .toList(),
                onChanged: (val) => setState(() => selectedRole = val!),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: departmentController,
                decoration: const InputDecoration(
                  labelText: 'Department (Optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isEmpty) return;

                Navigator.pop(context); // Close dialog
                _addMember(
                  email,
                  selectedRole,
                  departmentController.text.trim(),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addMember(
    String email,
    MemberRole role,
    String department,
  ) async {
    setState(() => _isLoading = true);
    try {
      await _orgService.addMemberByEmail(
        organizationId: widget.organizationId,
        email: email,
        role: role,
        department: department.isEmpty ? null : department,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Member added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showEditMemberSheet(MemberModel member) async {
    final departmentController = TextEditingController(text: member.department);
    MemberRole selectedRole = member.role;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Edit ${member.fullName ?? member.email}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<MemberRole>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: 'Role'),
                items: MemberRole.values.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(
                      _RoleSelectionDialogState.getRoleDisplayName(role),
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => selectedRole = val!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: departmentController,
                decoration: const InputDecoration(labelText: 'Department'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  _updateMember(
                    member,
                    selectedRole,
                    departmentController.text.trim(),
                  );
                },
                child: const Text('Save Changes'),
              ),
              TextButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Remove Member'),
                      content: Text(
                        'Are you sure you want to remove ${member.fullName}?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Remove'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && mounted) {
                    Navigator.pop(context);
                    _removeMember(member);
                  }
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Remove Member'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateMember(
    MemberModel member,
    MemberRole role,
    String department,
  ) async {
    setState(() => _isLoading = true);
    try {
      await _orgService.updateMemberRole(
        memberId: member.id,
        role: role,
        department: department.isEmpty ? null : department,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member updated successfully')),
        );
        _loadData();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _removeMember(MemberModel member) async {
    setState(() => _isLoading = true);
    try {
      await _orgService.removeMember(member.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Member removed')));
        _loadData();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
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
                title: Text(getRoleDisplayName(role)),
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

  static String getRoleDisplayName(MemberRole role) {
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

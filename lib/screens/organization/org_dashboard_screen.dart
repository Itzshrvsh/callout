import 'package:flutter/material.dart';
import '../../models/organization_model.dart';
import '../../models/member_model.dart';
import '../../services/organization_service.dart';
import '../../services/auth_service.dart';
import '../requests/create_request_screen.dart';
import '../requests/my_requests_screen.dart';
import '../requests/pending_approvals_screen.dart';
import 'manage_members_screen.dart';

class OrgDashboardScreen extends StatefulWidget {
  final OrganizationModel organization;

  const OrgDashboardScreen({super.key, required this.organization});

  @override
  State<OrgDashboardScreen> createState() => _OrgDashboardScreenState();
}

class _OrgDashboardScreenState extends State<OrgDashboardScreen> {
  final OrganizationService _orgService = OrganizationService();
  final AuthService _authService = AuthService();
  MemberModel? _currentMember;
  List<MemberModel> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final members = await _orgService.getOrganizationMembers(
        widget.organization.id,
      );
      final currentUserId = _authService.currentUser?.id;

      setState(() {
        _members = members;
        if (members.isEmpty) {
          _currentMember = null;
        } else {
          _currentMember = members.firstWhere(
            (m) => m.userId == currentUserId,
            orElse: () => members.first,
          );
        }
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

  bool get isAdmin => _currentMember?.role == MemberRole.admin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.organization.name),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ManageMembersScreen(
                      organizationId: widget.organization.id,
                    ),
                  ),
                );
              },
              tooltip: 'Manage Members',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Organization info card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                                  child: Text(
                                    widget.organization.name[0].toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.organization.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      if (widget.organization.description !=
                                          null)
                                        Text(
                                          widget.organization.description!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: Colors.grey[600],
                                              ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatItem(
                                  context,
                                  '${_members.length}',
                                  'Members',
                                  Icons.people,
                                ),
                                _buildStatItem(
                                  context,
                                  _currentMember?.getRoleDisplayName() ?? '-',
                                  'Your Role',
                                  Icons.badge,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick actions
                    Text(
                      'Quick Actions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildActionButton(
                      context,
                      'Create Request',
                      'Submit a new request to your team',
                      Icons.send,
                      Colors.blue,
                      () {
                        if (_currentMember != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CreateRequestScreen(
                                organizationId: widget.organization.id,
                                memberId: _currentMember!.id,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 8),

                    _buildActionButton(
                      context,
                      'My Requests',
                      'View all your submitted requests',
                      Icons.list_alt,
                      Colors.green,
                      () {
                        if (_currentMember != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MyRequestsScreen(
                                memberId: _currentMember!.id,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 8),

                    _buildActionButton(
                      context,
                      'Pending Approvals',
                      'Review requests waiting for your approval',
                      Icons.approval,
                      Colors.orange,
                      () {
                        if (_currentMember != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PendingApprovalsScreen(
                                memberId: _currentMember!.id,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 8),

                    if (isAdmin) ...[
                      _buildActionButton(
                        context,
                        'Manage Members',
                        'View and manage organization members',
                        Icons.manage_accounts,
                        Colors.purple,
                        () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ManageMembersScreen(
                                organizationId: widget.organization.id,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String value,
    String label,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

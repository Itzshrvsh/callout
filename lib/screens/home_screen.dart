import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/organization_service.dart';
import '../models/organization_model.dart';
import 'organization/create_org_screen.dart';
import 'organization/join_org_screen.dart';
import 'organization/org_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final OrganizationService _orgService = OrganizationService();
  List<OrganizationModel> _organizations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrganizations();
  }

  Future<void> _loadOrganizations() async {
    setState(() => _isLoading = true);
    try {
      final orgs = await _orgService.getUserOrganizations();
      setState(() {
        _organizations = orgs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading organizations: $e')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      await authService.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error signing out: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Callout'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadOrganizations,
              child: _organizations.isEmpty
                  ? _buildEmptyState()
                  : _buildOrganizationList(),
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateOrgScreen()),
              );
              if (result == true) _loadOrganizations();
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Org'),
            heroTag: 'create_org',
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            onPressed: () async {
              final result = await Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const JoinOrgScreen()));
              if (result == true) _loadOrganizations();
            },
            icon: const Icon(Icons.group_add),
            label: const Text('Join Org'),
            heroTag: 'join_org',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.corporate_fare, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Organizations Yet',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new organization or join an existing one to get started',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrganizationList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _organizations.length,
      itemBuilder: (context, index) {
        final org = _organizations[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                org.name[0].toUpperCase(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              org.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: org.description != null
                ? Text(
                    org.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OrgDashboardScreen(organization: org),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import '../../services/organization_service.dart';
import '../../models/organization_model.dart';

class JoinOrgScreen extends StatefulWidget {
  const JoinOrgScreen({super.key});

  @override
  State<JoinOrgScreen> createState() => _JoinOrgScreenState();
}

class _JoinOrgScreenState extends State<JoinOrgScreen> {
  final _searchController = TextEditingController();
  final _messageController = TextEditingController();
  final OrganizationService _orgService = OrganizationService();
  List<OrganizationModel> _searchResults = [];
  bool _isSearching = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _searchController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _searchOrganizations() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final results = await _orgService.searchOrganizations(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Search failed: $e')));
      }
    }
  }

  Future<void> _requestToJoin(OrganizationModel org) async {
    setState(() => _isSubmitting = true);

    try {
      await _orgService.requestToJoin(
        organizationId: org.id,
        message: _messageController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Join request sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showJoinDialog(OrganizationModel org) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Join ${org.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (org.description != null) ...[
                Text(org.description!),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Message to Admin (Optional)',
                  hintText: 'Introduce yourself...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isSubmitting
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      _requestToJoin(org);
                    },
              child: const Text('Send Request'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Organization')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Organizations',
                hintText: 'Enter organization name',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchResults = []);
                  },
                ),
              ),
              onSubmitted: (_) => _searchOrganizations(),
            ),
          ),

          // Search results
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Search for organizations',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final org = _searchResults[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            child: Text(
                              org.name[0].toUpperCase(),
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
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
                          trailing: ElevatedButton(
                            onPressed: () => _showJoinDialog(org),
                            child: const Text('Join'),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _searchOrganizations,
        child: const Icon(Icons.search),
      ),
    );
  }
}

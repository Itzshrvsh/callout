import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/request_model.dart';
import '../../services/request_service.dart';
import 'request_detail_screen.dart';

class MyRequestsScreen extends StatefulWidget {
  final String memberId;

  const MyRequestsScreen({super.key, required this.memberId});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  final RequestService _requestService = RequestService();
  List<RequestModel> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final requests = await _requestService.getMyRequests(widget.memberId);
      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading requests: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Requests')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRequests,
              child: _requests.isEmpty
                  ? _buildEmptyState()
                  : _buildRequestsList(),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Requests Yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _requests.length,
      itemBuilder: (context, index) {
        final request = _requests[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RequestDetailScreen(requestId: request.id),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          request.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      _buildStatusChip(request.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    request.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.category, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        request.requestType.toUpperCase(),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.priority_high,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        request.getImportanceDisplayName(),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('MMM d, y').format(request.createdAt),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(RequestStatus status) {
    Color color;
    switch (status) {
      case RequestStatus.pending:
        color = Colors.orange;
        break;
      case RequestStatus.approved:
        color = Colors.green;
        break;
      case RequestStatus.rejected:
        color = Colors.red;
        break;
      case RequestStatus.escalated:
        color = Colors.blue;
        break;
    }

    return Chip(
      label: Text(
        status.name.toUpperCase(),
        style: const TextStyle(fontSize: 12),
      ),
      backgroundColor: color.withValues(alpha: 0.2),
      side: BorderSide(color: color),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

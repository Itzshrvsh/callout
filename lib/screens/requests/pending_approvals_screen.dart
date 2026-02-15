import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/request_model.dart';
import '../../services/request_service.dart';
import 'request_detail_screen.dart';

class PendingApprovalsScreen extends StatefulWidget {
  final String memberId;

  const PendingApprovalsScreen({super.key, required this.memberId});

  @override
  State<PendingApprovalsScreen> createState() => _PendingApprovalsScreenState();
}

class _PendingApprovalsScreenState extends State<PendingApprovalsScreen> {
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
      final requests = await _requestService.getPendingApprovals(
        widget.memberId,
      );
      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading approvals: $e')));
      }
    }
  }

  Future<void> _approveRequest(RequestModel request) async {
    final comments = await _showCommentsDialog(
      'Approve Request',
      'Add approval comments (optional)',
    );
    if (comments == null) return; // User cancelled

    try {
      await _requestService.approveRequest(
        requestId: request.id,
        approverId: widget.memberId,
        comments: comments.isEmpty ? null : comments,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request approved!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectRequest(RequestModel request) async {
    final comments = await _showCommentsDialog(
      'Reject Request',
      'Reason for rejection',
    );
    if (comments == null) return;

    try {
      await _requestService.rejectRequest(
        requestId: request.id,
        approverId: widget.memberId,
        comments: comments.isEmpty ? null : comments,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Request rejected')));
        _loadRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _escalateRequest(RequestModel request) async {
    final reason = await _showCommentsDialog(
      'Escalate Request',
      'Reason for escalation',
    );
    if (reason == null) return;

    try {
      await _requestService.escalateRequest(
        requestId: request.id,
        currentApproverId: widget.memberId,
        reason: reason.isEmpty ? null : reason,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request escalated'),
            backgroundColor: Colors.blue,
          ),
        );
        _loadRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<String?> _showCommentsDialog(String title, String hint) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pending Approvals')),
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
          Icon(Icons.done_all, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'All Caught Up!',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No pending approvals',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
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
                      CircleAvatar(
                        child: Text(
                          (request.creatorName ?? 'U')[0].toUpperCase(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.creatorName ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              request.creatorEmail ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildImportanceChip(request.importanceLevel),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    request.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    request.description,
                    maxLines: 3,
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
                      const Spacer(),
                      Text(
                        DateFormat('MMM d, y').format(request.createdAt),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _rejectRequest(request),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Reject'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => _escalateRequest(request),
                        icon: const Icon(Icons.arrow_upward, size: 18),
                        label: const Text('Escalate'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _approveRequest(request),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
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

  Widget _buildImportanceChip(ImportanceLevel level) {
    Color color;
    switch (level) {
      case ImportanceLevel.low:
        color = Colors.grey;
        break;
      case ImportanceLevel.medium:
        color = Colors.blue;
        break;
      case ImportanceLevel.high:
        color = Colors.orange;
        break;
      case ImportanceLevel.critical:
        color = Colors.red;
        break;
    }

    return Chip(
      label: Text(
        level.name.toUpperCase(),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
      backgroundColor: color.withValues(alpha: 0.2),
      side: BorderSide(color: color),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

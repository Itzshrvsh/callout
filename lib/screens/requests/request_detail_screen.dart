import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/request_model.dart';
import '../../services/request_service.dart';
import '../../services/voice_service.dart';

class RequestDetailScreen extends StatefulWidget {
  final String requestId;

  const RequestDetailScreen({super.key, required this.requestId});

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  final RequestService _requestService = RequestService();
  // Voice Service is needed here
  late VoiceService _voiceService;
  RequestModel? _request;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _voiceService = VoiceService();
    _loadRequest();
  }

  @override
  void dispose() {
    _voiceService.stop();
    _voiceService.dispose();
    super.dispose();
  }

  Future<void> _loadRequest() async {
    setState(() => _isLoading = true);
    try {
      final request = await _requestService.getRequestById(widget.requestId);
      setState(() {
        _request = request;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading request: $e')));
      }
    }
  }

  Future<void> _handleVoiceInteraction() async {
    if (_request == null) return;

    // 1. Speak the request
    await _voiceService.speakRequest(_request!);

    if (!mounted) return;

    // Show listening snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Listening... Say "Approve", "Reject", or "Stop"'),
        duration: Duration(seconds: 10),
        backgroundColor: Colors.blueAccent,
      ),
    );

    // 2. Listen for command
    final command = await _voiceService.listenForCommand();

    if (!mounted) return;

    if (command == 'approved') {
      _processApproval(true);
    } else if (command == 'rejected') {
      _processApproval(false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice command not recognized or cancelled'),
        ),
      );
    }
  }

  Future<void> _processApproval(bool approve) async {
    try {
      final approverId = _request!.currentApproverId ?? '';

      if (approve) {
        await _requestService.approveRequest(
          requestId: _request!.id,
          approverId: approverId,
          comments: 'Approved via Voice 🎤',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request Approved via Voice! 🎤')),
          );
        }
      } else {
        await _requestService.rejectRequest(
          requestId: _request!.id,
          approverId: approverId,
          comments: 'Rejected via Voice 🎤',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request Rejected via Voice! 🎤')),
          );
        }
      }
      // Refresh
      _loadRequest();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing voice command: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request Details')),
      floatingActionButton:
          _request != null && _request!.status == RequestStatus.pending
          ? ListenableBuilder(
              listenable: _voiceService,
              builder: (context, child) {
                return FloatingActionButton.extended(
                  onPressed:
                      _voiceService.isSpeaking || _voiceService.isListening
                      ? _voiceService.stop
                      : _handleVoiceInteraction,
                  icon: Icon(
                    _voiceService.isListening
                        ? Icons.mic
                        : _voiceService.isSpeaking
                        ? Icons.volume_up
                        : Icons.record_voice_over,
                  ),
                  label: Text(
                    _voiceService.isListening
                        ? 'Listening...'
                        : _voiceService.isSpeaking
                        ? 'Speaking...'
                        : 'Voice Approve',
                  ),
                  backgroundColor: _voiceService.isListening
                      ? Colors.redAccent
                      : null,
                );
              },
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          // ... (Rest of body remains same)
          : _request == null
          ? const Center(child: Text('Request not found'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status card
                  Card(
                    color: _getStatusColor(_request!.status),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(
                            _getStatusIcon(_request!.status),
                            size: 48,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _request!.status.name.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    _request!.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Metadata
                  _buildInfoRow('Type', _request!.requestType.toUpperCase()),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    'Priority',
                    _request!.getImportanceDisplayName(),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    'Submitted',
                    DateFormat(
                      'MMM d, y \'at\' h:mm a',
                    ).format(_request!.createdAt),
                  ),
                  if (_request!.creatorName != null) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow('Submitted by', _request!.creatorName!),
                  ],
                  const Divider(height: 32),

                  // Description
                  Text(
                    'Description',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_request!.description),
                    ),
                  ),

                  // Additional metadata
                  if (_request!.metadata.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Additional Details',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _request!.metadata.entries.map((entry) {
                            if (entry.key == 'llm_reasoning')
                              return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildInfoRow(
                                _formatKey(entry.key),
                                entry.value.toString(),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],

                  // AI Reasoning
                  if (_request!.metadata['llm_reasoning'] != null) ...[
                    const SizedBox(height: 24),
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.psychology,
                                  color: Colors.blue.shade700,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'AI Analysis',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _request!.metadata['llm_reasoning'].toString(),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue.shade700,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  String _formatKey(String key) {
    return key
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Color _getStatusColor(RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
        return Colors.orange;
      case RequestStatus.approved:
        return Colors.green;
      case RequestStatus.rejected:
        return Colors.red;
      case RequestStatus.escalated:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
        return Icons.hourglass_empty;
      case RequestStatus.approved:
        return Icons.check_circle;
      case RequestStatus.rejected:
        return Icons.cancel;
      case RequestStatus.escalated:
        return Icons.arrow_upward;
    }
  }
}

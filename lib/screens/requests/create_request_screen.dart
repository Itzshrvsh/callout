import 'package:flutter/material.dart';
import '../../services/request_service.dart';
import '../../services/llm_service.dart';
import 'dart:async';

class CreateRequestScreen extends StatefulWidget {
  final String organizationId;
  final String memberId;

  const CreateRequestScreen({
    super.key,
    required this.organizationId,
    required this.memberId,
  });

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final RequestService _requestService = RequestService();
  final LLMService _llmService = LLMService();

  bool _isSubmitting = false;
  bool _isAnalyzing = false;
  LLMClassificationResult? _classification;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(_onDescriptionChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onDescriptionChanged() {
    // Debounce LLM analysis
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1000), () {
      if (_titleController.text.isNotEmpty &&
          _descriptionController.text.isNotEmpty) {
        _analyzeRequest();
      }
    });
  }

  Future<void> _analyzeRequest() async {
    setState(() => _isAnalyzing = true);
    try {
      final result = await _llmService.classifyRequest(
        title: _titleController.text,
        description: _descriptionController.text,
      );
      setState(() {
        _classification = result;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() => _isAnalyzing = false);
      // Silently fail - classification is optional
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await _requestService.createRequest(
        organizationId: widget.organizationId,
        memberId: widget.memberId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Request')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info card
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'AI will analyze your request and route it to the appropriate person',
                          style: TextStyle(color: Colors.blue.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Title field
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Request Title',
                  hintText: 'e.g., Annual Leave Request',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description field
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Provide details about your request...',
                  prefixIcon: const Icon(Icons.description),
                  suffixIcon: _isAnalyzing
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  if (value.length < 10) {
                    return 'Description must be at least 10 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // AI Analysis preview
              if (_classification != null) ...[
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.psychology,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'AI Analysis',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        _buildAnalysisRow(
                          'Type',
                          _classification!.requestType.toUpperCase(),
                        ),
                        const SizedBox(height: 8),
                        _buildAnalysisRow(
                          'Priority',
                          _classification!.importanceLevel.name.toUpperCase(),
                        ),
                        if (_classification!.reasoning.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Reason: ${_classification!.reasoning}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Submit button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Submit Request'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        Chip(label: Text(value), backgroundColor: Colors.white),
      ],
    );
  }
}

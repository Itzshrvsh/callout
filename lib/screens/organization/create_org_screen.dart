import 'package:flutter/material.dart';
import '../../services/organization_service.dart';

class CreateOrgScreen extends StatefulWidget {
  const CreateOrgScreen({super.key});

  @override
  State<CreateOrgScreen> createState() => _CreateOrgScreenState();
}

class _CreateOrgScreenState extends State<CreateOrgScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final OrganizationService _orgService = OrganizationService();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createOrganization() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _orgService.createOrganization(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Organization created successfully!'),
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
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Organization')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.business,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Create Your Organization',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'You will be the admin of this organization',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Organization name field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Organization Name',
                  prefixIcon: Icon(Icons.corporate_fare),
                  hintText: 'e.g., Acme Corp',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter organization name';
                  }
                  if (value.length < 3) {
                    return 'Name must be at least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description field
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  prefixIcon: Icon(Icons.description_outlined),
                  hintText: 'Briefly describe your organization',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),

              // Create button
              ElevatedButton(
                onPressed: _isLoading ? null : _createOrganization,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create Organization'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

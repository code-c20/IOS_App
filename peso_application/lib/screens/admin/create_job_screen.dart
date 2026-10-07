import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/job.dart';
import '../../providers/auth_provider.dart';
import '../../providers/job_provider.dart';
import '../../utils/constants.dart';
import 'package:peso_application/utils/app_feedback.dart';

class AdminCreateJobScreen extends StatefulWidget {
  const AdminCreateJobScreen({super.key});

  @override
  State<AdminCreateJobScreen> createState() => _AdminCreateJobScreenState();
}

class _AdminCreateJobScreenState extends State<AdminCreateJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController();
  final _locationController = TextEditingController();
  final _salaryController = TextEditingController();
  final _requirementsController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _daysController = TextEditingController(text: '30');
  bool _isFullTime = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _locationController.dispose();
    _salaryController.dispose();
    _requirementsController.dispose();
    _descriptionController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter $label.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final admin = authProvider.currentUser;
    if (admin == null || admin.role != AppConstants.roleAdmin) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(content: Text('An administrator account is required.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final jobProvider = context.read<JobProvider>();
    final now = DateTime.now();
    final job = Job(
      id: const Uuid().v4(),
      title: _titleController.text.trim(),
      category: _categoryController.text.trim(),
      description: _descriptionController.text.trim(),
      employerName: admin.name,
      employerId: '',
      location: _locationController.text.trim(),
      salary: _salaryController.text.trim(),
      isFullTime: _isFullTime,
      requirements: _requirementsController.text
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(),
      applicantCount: 0,
      postedDate: now,
      deadline: now.add(Duration(days: int.parse(_daysController.text.trim()))),
    );
    final success = await jobProvider.createJob(job);
    if (!mounted) return;

    setState(() => _isSubmitting = false);
    if (!success) {
      final error = jobProvider.error;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text(
            error == null || error.isEmpty
                ? 'Could not post the job.'
                : 'Could not post the job: $error',
          ),
          backgroundColor: const Color(AppConstants.dangerColor),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showAppSnackBar(
      const SnackBar(
        content: Text('Admin job posted successfully.'),
        backgroundColor: Color(AppConstants.successColor),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null || user.role != AppConstants.roleAdmin) {
      return const Scaffold(
        body: Center(child: Text('Administrator access is required.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Post an admin job')),
      backgroundColor: const Color(AppConstants.backgroundColor),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'This job will be published under the administrator account.',
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Job title'),
                validator: (value) => _required(value, 'a job title'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
                validator: (value) => _required(value, 'a category'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Location'),
                validator: (value) => _required(value, 'a location'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _salaryController,
                decoration: const InputDecoration(labelText: 'Salary range'),
                validator: (value) => _required(value, 'a salary range'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<bool>(
                initialValue: _isFullTime,
                decoration: const InputDecoration(labelText: 'Job type'),
                items: const [
                  DropdownMenuItem(value: true, child: Text('Full-time')),
                  DropdownMenuItem(value: false, child: Text('Part-time')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _isFullTime = value);
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _daysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Application period (days)',
                ),
                validator: (value) {
                  final days = int.tryParse(value?.trim() ?? '');
                  if (days == null || days < 1 || days > 365) {
                    return 'Enter a number from 1 to 365.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _requirementsController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Requirements (one per line)',
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Enter at least one requirement.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descriptionController,
                minLines: 5,
                maxLines: 10,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (value) => _required(value, 'a description'),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.post_add),
                label: Text(_isSubmitting ? 'Posting...' : 'Publish admin job'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

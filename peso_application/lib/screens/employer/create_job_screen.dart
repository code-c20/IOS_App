import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/job.dart';
import '../../providers/auth_provider.dart';
import '../../providers/job_provider.dart';
import '../../utils/constants.dart';
import 'package:peso_application/utils/app_feedback.dart';

class EmployerCreateJobScreen extends StatefulWidget {
  const EmployerCreateJobScreen({super.key});

  @override
  State<EmployerCreateJobScreen> createState() =>
      _EmployerCreateJobScreenState();
}

class _EmployerCreateJobScreenState extends State<EmployerCreateJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _salaryController = TextEditingController();
  final _applicationDaysController = TextEditingController(text: '30');
  final _descriptionController = TextEditingController();
  final _requirementsController = TextEditingController();
  final _customCategoryController = TextEditingController();
  String _jobType = 'Full-time';
  String _category = 'Office Assistant';
  String _location = 'Kidapawan City';
  bool _isSubmitting = false;

  final _categories = [
    'Office Assistant',
    'Sales Associate',
    'IT Support Specialist',
    'Customer Service',
    'Other',
  ];

  final _locations = [
    'Kidapawan City',
    'Davao City',
    'Cotabato City',
    'General Santos',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _salaryController.dispose();
    _applicationDaysController.dispose();
    _descriptionController.dispose();
    _requirementsController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;

    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundColor),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Theme.of(context).primaryColor,
        title: const Text('Create Job'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF075443), Color(0xFF0B8F78)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(28),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.post_add_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create a strong listing',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Attract the right candidates with clear details.',
                            style: TextStyle(
                              color: Colors.white70,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const _FormSectionHeader(
                        icon: Icons.badge_outlined,
                        title: 'Role details',
                        subtitle:
                            'Tell candidates what this position is about.',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Job Title',
                          prefixIcon: Icon(Icons.work_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a job title.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        items: _categories
                            .map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              ),
                            )
                            .toList(),
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _category = value);
                          }
                        },
                      ),
                      if (_category == 'Other') ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _customCategoryController,
                          decoration: const InputDecoration(
                            labelText: 'Other category',
                            prefixIcon: Icon(Icons.edit_outlined),
                            hintText: 'Enter a custom category',
                          ),
                          validator: (value) {
                            if (_category == 'Other' &&
                                (value == null || value.trim().isEmpty)) {
                              return 'Please enter a job category.';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _jobType,
                        items: const [
                          DropdownMenuItem(
                            value: 'Full-time',
                            child: Text('Full-time'),
                          ),
                          DropdownMenuItem(
                            value: 'Part-time',
                            child: Text('Part-time'),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Job Type',
                          prefixIcon: Icon(Icons.schedule_outlined),
                        ),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _jobType = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _location,
                        items: _locations
                            .map(
                              (location) => DropdownMenuItem(
                                value: location,
                                child: Text(location),
                              ),
                            )
                            .toList(),
                        decoration: const InputDecoration(
                          labelText: 'Location',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _location = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _salaryController,
                        decoration: const InputDecoration(
                          labelText: 'Salary Range',
                          prefixIcon: Icon(Icons.attach_money),
                          hintText: 'e.g. ₱15,000 - ₱20,000',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a salary range.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      const _FormSectionHeader(
                        icon: Icons.event_available_outlined,
                        title: 'Application window',
                        subtitle: 'Choose how long candidates can apply.',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _applicationDaysController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Application period',
                          hintText: 'e.g. 30',
                          prefixIcon: Icon(Icons.event_available_outlined),
                          suffixText: 'days',
                        ),
                        validator: (value) {
                          final days = int.tryParse(value?.trim() ?? '');
                          if (days == null || days < 1) {
                            return 'Enter at least 1 day for applications.';
                          }
                          if (days > 365) {
                            return 'Application period cannot exceed 365 days.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Applications will close automatically after this period.',
                          style: TextStyle(
                            color: Colors.blueGrey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const _FormSectionHeader(
                        icon: Icons.description_outlined,
                        title: 'Job overview',
                        subtitle:
                            'Describe the responsibilities and qualifications.',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _requirementsController,
                        minLines: 3,
                        maxLines: 7,
                        decoration: const InputDecoration(
                          labelText: 'Requirements',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.checklist_outlined),
                          hintText:
                              'Add one requirement per line, e.g.\nBachelor\'s degree\nGood communication skills\n1 year of experience',
                        ),
                        validator: (value) {
                          final requirements = (value ?? '')
                              .split('\n')
                              .where((line) => line.trim().isNotEmpty)
                              .toList();
                          if (requirements.isEmpty) {
                            return 'Please add at least one requirement.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        minLines: 5,
                        maxLines: 10,
                        decoration: const InputDecoration(
                          labelText: 'Job Description',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.description_outlined),
                          hintText:
                              'Describe duties, qualifications, and benefits.',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a job description.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: _isSubmitting || currentUser == null
                              ? null
                              : () async {
                                  if (!_formKey.currentState!.validate()) {
                                    return;
                                  }

                                  setState(() => _isSubmitting = true);

                                  final jobProvider = context
                                      .read<JobProvider>();
                                  final scaffoldMessenger =
                                      ScaffoldMessenger.of(context);
                                  final navigator = Navigator.of(context);
                                  final postedDate = DateTime.now();
                                  final applicationDays = int.parse(
                                    _applicationDaysController.text.trim(),
                                  );
                                  final job = Job(
                                    id: const Uuid().v4(),
                                    title: _titleController.text.trim(),
                                    category: _category == 'Other'
                                        ? _customCategoryController.text.trim()
                                        : _category,
                                    description: _descriptionController.text
                                        .trim(),
                                    employerName: currentUser.name,
                                    employerId:
                                        currentUser.role ==
                                            AppConstants.roleEmployer
                                        ? currentUser.id
                                        : '',
                                    location: _location,
                                    salary: _salaryController.text.trim(),
                                    isFullTime: _jobType == 'Full-time',
                                    requirements: _requirementsController.text
                                        .trim()
                                        .split('\n')
                                        .where((line) => line.trim().isNotEmpty)
                                        .toList(),
                                    applicantCount: 0,
                                    postedDate: postedDate,
                                    deadline: postedDate.add(
                                      Duration(days: applicationDays),
                                    ),
                                  );

                                  final success = await jobProvider.createJob(
                                    job,
                                  );
                                  if (!mounted) return;
                                  setState(() => _isSubmitting = false);

                                  if (success) {
                                    scaffoldMessenger.showAppSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Job posted successfully!',
                                        ),
                                        backgroundColor: Color(
                                          AppConstants.successColor,
                                        ),
                                      ),
                                    );
                                    navigator.pop();
                                  } else {
                                    final error = jobProvider.error;
                                    scaffoldMessenger.showAppSnackBar(
                                      SnackBar(
                                        content: Text(
                                          error == null || error.isEmpty
                                              ? 'Could not post job. Try again.'
                                              : 'Could not post job: $error',
                                        ),
                                        backgroundColor: Color(
                                          AppConstants.dangerColor,
                                        ),
                                      ),
                                    );
                                  }
                                },
                          child: _isSubmitting
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text('Publish Job'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FormSectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(AppConstants.primaryColor).withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 19,
            color: const Color(AppConstants.primaryColor),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(AppConstants.textDark),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blueGrey.shade600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

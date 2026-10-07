import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/job_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/job_card.dart';
import '../../widgets/branded_app_bar.dart';
import 'job_details_screen.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  final _searchController = TextEditingController();
  String? _selectedCategory = 'All';
  String? _selectedLocation = 'All';
  String _selectedJobType = 'All';

  // Make categories/locations mutable so we can add custom "Other" values at runtime
  List<String> categories = [
    'All',
    'Administrative',
    'Marketing',
    'Sales',
    'IT',
    'HR',
    'Other',
  ];
  List<String> locations = [
    'All',
    'Kidapawan City',
    'Davao City',
    'General Santos',
    'Cotabato City',
    'Other',
  ];
  final jobTypes = ['All', 'Full-time', 'Part-time'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<JobProvider>().fetchJobs();
    });
  }

  Future<void> _refreshJobs() async {
    await context.read<JobProvider>().fetchJobs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundColor),
      appBar: const BrandedAppBar(
        title: 'Browse Jobs',
        gradientColors: [Color(0xFF075443), Color(0xFF0B8F78)],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Limit the filter panel height and make it scrollable to avoid overflow
            ConstrainedBox(
              constraints: BoxConstraints(
                // allow the panel to take up to 55% of the viewport height (increased)
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                // slightly reduced vertical padding to avoid small-screen overflow
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(13),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  // allow scrolling inside the panel when space is constrained
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search jobs...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: const Color(0xFFF5F7FB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _FilterDropdown<String>(
                              value: _selectedCategory,
                              label: 'Category',
                              options: categories,
                              onChanged: (value) async {
                                if (value == 'Other') {
                                  final input = await _promptCustom(
                                    context,
                                    'Category',
                                  );
                                  if (input != null &&
                                      input.trim().isNotEmpty) {
                                    setState(() {
                                      // insert custom value after 'All' so it appears near top
                                      categories.insert(1, input.trim());
                                      _selectedCategory = input.trim();
                                    });
                                  }
                                } else {
                                  setState(() => _selectedCategory = value);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _FilterDropdown<String>(
                              value: _selectedLocation,
                              label: 'Location',
                              options: locations,
                              onChanged: (value) async {
                                if (value == 'Other') {
                                  final input = await _promptCustom(
                                    context,
                                    'Location',
                                  );
                                  if (input != null &&
                                      input.trim().isNotEmpty) {
                                    setState(() {
                                      locations.insert(1, input.trim());
                                      _selectedLocation = input.trim();
                                    });
                                  }
                                } else {
                                  setState(() => _selectedLocation = value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: jobTypes.map((type) {
                          final selected = _selectedJobType == type;
                          return ChoiceChip(
                            label: Text(type),
                            selected: selected,
                            selectedColor: const Color(
                              AppConstants.primaryColor,
                            ),
                            backgroundColor: Colors.grey[200],
                            labelStyle: TextStyle(
                              color: selected ? Colors.white : Colors.black87,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                            onSelected: (_) =>
                                setState(() => _selectedJobType = type),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Consumer<JobProvider>(
                builder: (context, jobProvider, _) {
                  final jobs = jobProvider.jobs;
                  return RefreshIndicator(
                    onRefresh: _refreshJobs,
                    child: jobProvider.isLoading
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            children: const [
                              SizedBox(height: 120),
                              Center(child: CircularProgressIndicator()),
                            ],
                          )
                        : Builder(
                            builder: (context) {
                              final filteredJobs = jobs.where((job) {
                                final searchText = _searchController.text
                                    .toLowerCase();
                                final matchesSearch =
                                    searchText.isEmpty ||
                                    job.title.toLowerCase().contains(
                                      searchText,
                                    ) ||
                                    job.employerName.toLowerCase().contains(
                                      searchText,
                                    );
                                final matchesCategory =
                                    _selectedCategory == 'All' ||
                                    job.category == _selectedCategory;
                                final matchesLocation =
                                    _selectedLocation == 'All' ||
                                    job.location == _selectedLocation;
                                final jobType = job.isFullTime
                                    ? 'Full-time'
                                    : 'Part-time';
                                final matchesJobType =
                                    _selectedJobType == 'All' ||
                                    jobType == _selectedJobType;
                                return matchesSearch &&
                                    matchesCategory &&
                                    matchesLocation &&
                                    matchesJobType;
                              }).toList();

                              if (filteredJobs.isEmpty) {
                                if (jobs.isEmpty && jobProvider.error != null) {
                                  return ListView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 8,
                                    ),
                                    children: [
                                      const SizedBox(height: 120),
                                      Icon(
                                        Icons.cloud_off_outlined,
                                        size: 64,
                                        color: Colors.grey[500],
                                      ),
                                      const SizedBox(height: 16),
                                      Center(
                                        child: Text(
                                          jobProvider.error!,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Center(
                                        child: OutlinedButton.icon(
                                          onPressed: _refreshJobs,
                                          icon: const Icon(Icons.refresh),
                                          label: const Text('Retry'),
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                return ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  children: [
                                    const SizedBox(height: 120),
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 32,
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.search_off_outlined,
                                              size: 72,
                                              color: Colors.grey[400],
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'No jobs found',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleLarge,
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Try changing the filters or searching for another job title.',
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }

                              return ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                itemCount: filteredJobs.length,
                                itemBuilder: (context, index) {
                                  final job = filteredJobs[index];
                                  return JobCard(
                                    job: job,
                                    isSaved: jobProvider.isJobSaved(job.id),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              JobDetailsScreen(job: job),
                                        ),
                                      );
                                    },
                                    onSavePressed: () {
                                      if (jobProvider.isJobSaved(job.id)) {
                                        jobProvider.unsaveJob(job.id);
                                      } else {
                                        jobProvider.saveJob(job);
                                      }
                                    },
                                  );
                                },
                              );
                            },
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<String?> _promptCustom(BuildContext context, String label) async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Enter custom $label'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: 'Enter $label'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    return result;
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  final T? value;
  final String label;
  final List<T> options;
  final ValueChanged<T?> onChanged;

  const _FilterDropdown({
    required this.value,
    required this.label,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      isExpanded: true,
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
        fillColor: Colors.grey[100],
      ),
      items: options.map((option) {
        return DropdownMenuItem(value: option, child: Text(option.toString()));
      }).toList(),
      onChanged: onChanged,
    );
  }
}

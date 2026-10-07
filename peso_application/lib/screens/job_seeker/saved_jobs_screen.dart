import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/job_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/job_card.dart';
import 'job_details_screen.dart';

class SavedJobsScreen extends StatelessWidget {
  const SavedJobsScreen({super.key});

  Future<void> _refreshSavedJobs(BuildContext context) async {
    await context.read<JobProvider>().refreshSavedJobs();
  }

  @override
  Widget build(BuildContext context) {
    final jobProvider = context.watch<JobProvider>();
    final savedJobs = jobProvider.savedJobs;

    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundColor),
      appBar: AppBar(title: const Text('Saved Jobs'), elevation: 0),
      body: RefreshIndicator(
        onRefresh: () => _refreshSavedJobs(context),
        child: savedJobs.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 32,
                ),
                children: [
                  Icon(
                    Icons.bookmark_border,
                    size: 86,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'No saved jobs yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Save jobs you like so you can review them later.',
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: savedJobs.length,
                itemBuilder: (context, index) {
                  final job = savedJobs[index];
                  return JobCard(
                    job: job,
                    isSaved: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => JobDetailsScreen(job: job),
                        ),
                      );
                    },
                    onSavePressed: () {
                      jobProvider.unsaveJob(job.id);
                    },
                  );
                },
              ),
      ),
    );
  }
}

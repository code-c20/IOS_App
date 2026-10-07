import 'package:flutter/material.dart';
import '../../models/report.dart';
import '../../services/supabase_service.dart';

class ReportHistoryScreen extends StatefulWidget {
  const ReportHistoryScreen({super.key, required this.userId});

  final String userId;

  @override
  State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
}

class _ReportHistoryScreenState extends State<ReportHistoryScreen> {
  final _supabaseService = SupabaseService();
  late Future<List<Report>> _reportsFuture;

  @override
  void initState() {
    super.initState();
    _reportsFuture = _loadReports();
  }

  Future<List<Report>> _loadReports() async {
    final rows = await _supabaseService.getUserReports(widget.userId);
    return rows.map(Report.fromJson).toList();
  }

  Future<void> _refresh() async {
    setState(() => _reportsFuture = _loadReports());
    await _reportsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report history'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh reports',
          ),
        ],
      ),
      body: FutureBuilder<List<Report>>(
        future: _reportsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.error_outline,
              message: 'Unable to load your report history.',
              action: _refresh,
            );
          }

          final reports = snapshot.data ?? [];
          if (reports.isEmpty) {
            return const _MessageState(
              icon: Icons.inbox_outlined,
              message: 'You have not submitted any reports yet.',
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: reports.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _ReportCard(report: reports[index]),
            ),
          );
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final Report report;

  Color _statusColor(BuildContext context) {
    switch (report.status) {
      case 'resolved':
        return Colors.green;
      case 'dismissed':
        return Colors.grey.shade700;
      case 'reviewed':
        return Theme.of(context).colorScheme.primary;
      default:
        return Colors.orange.shade800;
    }
  }

  String _statusLabel() {
    return report.status[0].toUpperCase() + report.status.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    report.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(24),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${report.category.replaceAll('_', ' ')}  |  ${report.formattedDate} at ${report.formattedTime}',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Text(report.description),
            if (report.adminNotes?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Update from PESO: ${report.adminNotes}'),
              ),
            ],
            if (report.reviewedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last updated ${report.reviewedAt!.toLocal().toString().split('.').first}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Future<void> Function()? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: action,
                child: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

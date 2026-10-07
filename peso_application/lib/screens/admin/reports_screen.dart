import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/constants.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/branded_app_bar.dart';
import 'package:peso_application/utils/app_feedback.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _filteredReports = [];
  bool _isLoading = true;
  String _selectedStatus = 'All';
  String _searchQuery = '';

  static const List<String> _statusOptions = [
    'All',
    'pending',
    'reviewed',
    'resolved',
    'dismissed',
  ];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final reports = await _supabaseService.getReports();
      setState(() {
        _reports = reports;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    _filteredReports = _reports.where((report) {
      final matchesStatus =
          _selectedStatus == 'All' || report['status'] == _selectedStatus;
      final matchesSearch =
          _searchQuery.isEmpty ||
          (report['title'] as String?)?.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ==
              true ||
          (report['description'] as String?)?.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ==
              true;
      return matchesStatus && matchesSearch;
    }).toList();
  }

  void _updateReportStatus(
    String reportId,
    String newStatus, {
    String? adminNotes,
  }) async {
    final adminId = context.read<AuthProvider>().currentUser?.id;

    if (adminId == null) return;

    final success = await _supabaseService.updateReportStatus(
      reportId: reportId,
      status: newStatus,
      adminNotes: adminNotes,
      reviewedByAdminId: adminId,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(content: Text('Report updated successfully')),
      );
      _loadReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundColor),
      appBar: const BrandedAppBar(title: 'User Reports'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                          _applyFilters();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search reports...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _statusOptions.map((status) {
                          final selected = _selectedStatus == status;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(status),
                              selected: selected,
                              onSelected: (_) {
                                setState(() {
                                  _selectedStatus = status;
                                  _applyFilters();
                                });
                              },
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
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_filteredReports.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.assessment_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No reports found',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...List.generate(_filteredReports.length, (index) {
                        final report = _filteredReports[index];
                        return _ReportItemCard(
                          report: report,
                          onStatusChange: (newStatus) =>
                              _updateReportStatus(report['id'], newStatus),
                        );
                      }),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ReportItemCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final Function(String) onStatusChange;

  const _ReportItemCard({required this.report, required this.onStatusChange});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'reviewed':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'dismissed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportType = report['report_type'] as String? ?? 'unknown';
    final category = report['category'] as String? ?? 'other';
    final status = report['status'] as String? ?? 'pending';
    final title = report['title'] as String? ?? 'No title';
    final description = report['description'] as String? ?? 'No description';
    final createdAt = report['created_at'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withAlpha(36),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    reportType.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (createdAt != null) ...[
                  Text(
                    'Reported: $createdAt',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  'Category: ${category.replaceAll('_', ' ').toUpperCase()}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Description:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(height: 1.5)),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['pending', 'reviewed', 'resolved', 'dismissed']
                        .map(
                          (s) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ElevatedButton(
                              onPressed: status != s
                                  ? () => onStatusChange(s)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _getStatusColor(s),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              child: Text(
                                s,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

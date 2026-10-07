import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'package:peso_application/utils/app_feedback.dart';

class TermsPolicyScreen extends StatefulWidget {
  const TermsPolicyScreen({super.key, this.canEdit = false});

  final bool canEdit;

  @override
  State<TermsPolicyScreen> createState() => _TermsPolicyScreenState();
}

class _TermsPolicyScreenState extends State<TermsPolicyScreen> {
  final _service = SupabaseService();
  late Future<Map<String, String>?> _policyFuture;

  @override
  void initState() {
    super.initState();
    _policyFuture = _service.getAppPolicy();
  }

  void _reload() {
    setState(() => _policyFuture = _service.getAppPolicy());
  }

  Future<void> _editPolicy(Map<String, String>? policy) async {
    final titleController = TextEditingController(
      text: policy?['title'] ?? 'Terms and Policies',
    );
    final bodyController = TextEditingController(
      text: policy?['body'] ?? _defaultPolicy,
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit terms and policies'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyController,
                minLines: 10,
                maxLines: 18,
                decoration: const InputDecoration(
                  labelText: 'Rules and protocols',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final body = bodyController.text.trim();
              if (title.isEmpty || body.isEmpty) return;
              final success = await _service.updateAppPolicy(
                title: title,
                body: body,
              );
              if (!dialogContext.mounted) return;
              if (success) {
                Navigator.pop(dialogContext, true);
              } else {
                ScaffoldMessenger.of(dialogContext).showAppSnackBar(
                  const SnackBar(
                    content: Text(
                      'Unable to save. Run the app_policies SQL setup in Supabase and verify that your account is an admin.',
                    ),
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    titleController.dispose();
    bodyController.dispose();
    if (!mounted || saved != true) return;
    _reload();
    ScaffoldMessenger.of(context).showAppSnackBar(
      const SnackBar(content: Text('Terms and policies updated.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms and Policies'),
        actions: [
          if (widget.canEdit)
            IconButton(
              tooltip: 'Edit terms and policies',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _policyFuture.then(_editPolicy),
            ),
        ],
      ),
      body: FutureBuilder<Map<String, String>?>(
        future: _policyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final policy = snapshot.data;
          final title = policy?['title'] ?? 'Terms and Policies';
          final body = policy?['body'] ?? _defaultPolicy;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.gavel_outlined,
                                color: Theme.of(context).primaryColor),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(title,
                                  style: Theme.of(context).textTheme.titleLarge),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(body, style: const TextStyle(height: 1.55)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

const _defaultPolicy = '''Account and access
- Keep your account information accurate and secure.
- Do not share your password or use another person's account.

Job postings
- Employers must publish truthful, lawful, and complete job information.
- Do not post discriminatory, fraudulent, or misleading opportunities.

Applications and communication
- Job seekers should submit accurate information and apply only to suitable roles.
- Use respectful language and do not harass, threaten, or misuse messaging.

Privacy and safety
- Do not share personal information obtained in the app without permission.
- Report suspicious activity, unsafe content, or policy violations to an administrator.

The administrator may review violations and suspend accounts or remove content when necessary.''';

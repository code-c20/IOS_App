import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/constants.dart';
import '../../providers/auth_provider.dart';
import 'login_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({required this.email, super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isResending = false;
  String? _resendMessage;

  Future<void> _resendConfirmation() async {
    setState(() {
      _isResending = true;
      _resendMessage = null;
    });
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.resendSignupConfirmation(widget.email);
    if (!mounted) return;
    setState(() {
      _isResending = false;
      _resendMessage = success
          ? 'Confirmation email requested. Check your inbox and spam folder.'
          : authProvider.error ?? 'Unable to resend the confirmation email.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email'), elevation: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Color(AppConstants.primaryColor),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.email_outlined,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Please verify your account',
                style: Theme.of(context).textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Your account has been created. Check ${widget.email} for a confirmation link. Check your spam folder if it is not in your inbox.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isResending ? null : _resendConfirmation,
                child: _isResending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Resend confirmation email'),
              ),
              if (_resendMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _resendMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _resendMessage!.startsWith('Confirmation')
                        ? Colors.green.shade800
                        : Colors.red.shade700,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text('Back to Login'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: const Text('I have confirmed my email'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/constants.dart';

class EmailVerifiedScreen extends StatefulWidget {
  const EmailVerifiedScreen({super.key});

  @override
  State<EmailVerifiedScreen> createState() => _EmailVerifiedScreenState();
}

class _EmailVerifiedScreenState extends State<EmailVerifiedScreen> {
  StreamSubscription<supabase.AuthState>? _authSubscription;
  bool _isLoading = true;
  bool _isNavigating = false;
  bool _profileLoadInProgress = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _authSubscription = SupabaseService().client.auth.onAuthStateChange.listen(
      (state) {
        if (state.session != null) {
          unawaited(_loadVerifiedAccount());
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _error = AuthProvider.formatErrorForUI(error);
        });
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadVerifiedAccount());
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadVerifiedAccount() async {
    if (!mounted || _isNavigating || _profileLoadInProgress) return;
    final authProvider = context.read<AuthProvider>();
    if (authProvider.currentUser != null) {
      _navigateToHome();
      return;
    }

    _profileLoadInProgress = true;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await authProvider.loadStoredUser();
      if (!mounted) return;

      if (authProvider.currentUser != null) {
        _navigateToHome();
        return;
      }

      setState(() {
        _isLoading = false;
        _error = authProvider.error;
      });
    } finally {
      _profileLoadInProgress = false;
    }
  }

  void _navigateToHome() {
    if (!mounted || _isNavigating) return;
    _isNavigating = true;
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1FBF7),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(16),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (_isLoading)
                      const SizedBox(
                        width: 56,
                        height: 56,
                        child: CircularProgressIndicator(),
                      )
                    else
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: Color(
                            _error == null
                                ? AppConstants.successColor
                                : AppConstants.warningColor,
                          ).withAlpha(24),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _error == null
                              ? Icons.verified_outlined
                              : Icons.info_outline,
                          color: Color(
                            _error == null
                                ? AppConstants.successColor
                                : AppConstants.warningColor,
                          ),
                          size: 52,
                        ),
                      ),
                    const SizedBox(height: 24),
                    Text(
                      _isLoading
                          ? 'Finishing account setup'
                          : _error == null
                          ? 'Your account is verified'
                          : 'Email verified; sign-in needed',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isLoading
                          ? 'We are preparing your account and role profile.'
                          : _error ??
                                'Your account is ready. Continue to sign in if you are not redirected automatically.',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                    if (!_isLoading) ...[
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _error == null
                              ? () => Navigator.of(
                                  context,
                                ).pushNamedAndRemoveUntil(
                                  '/login',
                                  (_) => false,
                                )
                              : _loadVerifiedAccount,
                          icon: Icon(
                            _error == null
                                ? Icons.login_outlined
                                : Icons.refresh,
                          ),
                          label: Text(
                            _error == null
                                ? 'Continue to sign in'
                                : 'Retry account setup',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

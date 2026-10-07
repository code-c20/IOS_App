import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import '../job_seeker/navigation_screen.dart' as job_seeker;
import '../../screens/employer/navigation_screen.dart';
import '../../screens/admin/navigation_screen.dart';
import 'role_selection_screen.dart';
import 'package:peso_application/utils/app_feedback.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.logoPath = AppConstants.loginLogoAsset});

  final String logoPath;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundColor),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withAlpha(35),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _LoginLogo(imagePath: widget.logoPath),
                  ),
                  const SizedBox(height: 14),
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Work',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                          ),
                        ),
                        TextSpan(
                          text: 'Nests',
                          style: TextStyle(
                            color: Color(0xFFFF9F43),
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'FILIPINO JOB MARKETPLACE',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 34),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFDCE5E2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(12),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome Back',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sign in to continue finding opportunities close to home.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 26),
                        Text(
                          'Email address',
                          style: theme.textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [
                            AutofillHints.username,
                            AutofillHints.email,
                          ],
                          decoration: const InputDecoration(
                            hintText: 'you@example.com',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text('Password', style: theme.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onSubmitted: (_) => _signIn(context),
                          decoration: InputDecoration(
                            hintText: 'Enter your password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Show password'
                                  : 'Hide password',
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _showPasswordReset,
                            child: const Text('Forgot password?'),
                          ),
                        ),
                        Consumer<AuthProvider>(
                          builder: (context, authProvider, _) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (authProvider.error != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.red.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          color: Colors.red.shade700,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            authProvider.error!,
                                            style: TextStyle(
                                              color: Colors.red.shade900,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                SizedBox(
                                  height: 52,
                                  child: FilledButton.icon(
                                    onPressed: authProvider.isLoading
                                        ? null
                                        : () => _signIn(context),
                                    icon: authProvider.isLoading
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.login_rounded,
                                            size: 19,
                                          ),
                                    label: Text(
                                      authProvider.isLoading
                                          ? 'Signing In...'
                                          : 'Sign In',
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                'NEW HERE?',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RoleSelectionScreen(),
                              ),
                            ),
                            child: const Text('Create an account'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Your next opportunity starts here.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPasswordReset() async {
    final email = _emailController.text.trim();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset password'),
        content: Text(
          email.isEmpty
              ? 'Enter your email in the Email field and press Reset.'
              : 'A password reset link will be sent to $email if it is registered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final scaffold = ScaffoldMessenger.of(context);
              final auth = context.read<AuthProvider>();
              Navigator.pop(dialogContext);
              if (email.isEmpty) {
                scaffold.showAppSnackBar(
                  const SnackBar(
                    content: Text('Please enter an email address.'),
                  ),
                );
                return;
              }

              final success = await auth.requestPasswordReset(email);
              if (!mounted) return;
              scaffold.showAppSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? 'If an account exists, a reset email was requested.'
                        : 'Failed to request password reset. Please try again later.',
                  ),
                ),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _signIn(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.isLoading) return;
    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (!context.mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(
          content: Text('Signed in successfully.'),
          duration: Duration(seconds: 2),
        ),
      );
      _navigateToDashboard(context, authProvider.currentUser!.role);
    }
  }

  void _navigateToDashboard(BuildContext context, String role) {
    Widget destination;
    switch (role) {
      case AppConstants.roleJobSeeker:
        destination = const job_seeker.JobSeekerNavigationScreen();
        break;
      case AppConstants.roleEmployer:
        destination = const EmployerNavigationScreen();
        break;
      case AppConstants.roleAdmin:
        destination = const AdminNavigationScreen();
        break;
      default:
        destination = const LoginScreen();
    }

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => destination));
  }
}

class _LoginLogo extends StatelessWidget {
  const _LoginLogo({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    final isSvg = imagePath.toLowerCase().endsWith('.svg');

    if (isSvg) {
      return SvgPicture.asset(
        imagePath,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.fill,
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      );
    }

    return Image.asset(
      imagePath,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      alignment: Alignment.center,
    );
  }
}

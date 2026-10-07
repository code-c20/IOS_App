import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import 'signup_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20),
              Text(
                'Choose Your Role',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              SizedBox(height: 8),
              Text(
                'Select the role that best describes you',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              SizedBox(height: 32),
              // Job Seeker Card
              _RoleCard(
                icon: Icons.work_history_outlined,
                title: 'Job Seeker',
                description: 'Browse and apply for jobs',
                isSelected: _selectedRole == AppConstants.roleJobSeeker,
                accentColor: AppConstants.jobSeekerColor,
                onTap: () {
                  setState(() => _selectedRole = AppConstants.roleJobSeeker);
                },
              ),
              SizedBox(height: 16),
              // Employer Card
              _RoleCard(
                icon: Icons.business_center_outlined,
                title: 'Employer',
                description: 'Post jobs and manage applicants',
                isSelected: _selectedRole == AppConstants.roleEmployer,
                accentColor: AppConstants.employerColor,
                onTap: () {
                  setState(() => _selectedRole = AppConstants.roleEmployer);
                },
              ),
              Spacer(),
              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _selectedRole != null
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  SignUpScreen(role: _selectedRole!),
                            ),
                          );
                        }
                      : null,
                  child: Text('Continue'),
                ),
              ),
              SizedBox(height: 16),
              // Back to Login
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Already have an account? '),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Text(
                      'Sign In',
                      style: TextStyle(
                        color: Color(AppConstants.primaryColor),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isSelected;
  final int accentColor;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Color(accentColor) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? Color.fromRGBO(
                  (accentColor >> 16) & 0xFF,
                  (accentColor >> 8) & 0xFF,
                  accentColor & 0xFF,
                  0.06,
                )
              : Colors.white,
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Color.fromRGBO(
                  (accentColor >> 16) & 0xFF,
                  (accentColor >> 8) & 0xFF,
                  accentColor & 0xFF,
                  0.12,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Color(accentColor),
                size: 32,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Color(accentColor),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}

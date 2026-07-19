import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/colors.dart';
import '../widgets/animated_button.dart';
import '../widgets/app_field.dart';
import 'check_email_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final AuthService _authService = AuthService();
  final TextEditingController emailController = TextEditingController();

  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (emailController.text.trim().isEmpty) {
      _showMessage('Please enter your email address.');
      return;
    }

    setState(() => isLoading = true);
    try {
      await _authService.sendPasswordResetEmail(emailController.text);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CheckEmailPage(email: emailController.text.trim()),
        ),
      );
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? 'Failed to send reset email.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLightMint,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Row(
                  children: [
                    Icon(Icons.arrow_back, color: kDarkGreen, size: 18),
                    SizedBox(width: 6),
                    Text('Back to login', style: TextStyle(color: kDarkGreen, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Center(
                child: Container(
                  height: 130,
                  width: 130,
                  decoration: BoxDecoration(
                    color: kHeaderGreen.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_reset, size: 60, color: kDarkGreen),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Forgot Password?',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: kDarkGreen),
              ),
              const SizedBox(height: 8),
              const Text(
                "No worries, we've got you. Enter your email and we'll send a link to reset it.",
                style: TextStyle(color: kFieldGrey, fontSize: 14),
              ),
              const SizedBox(height: 28),

              AppField(
                controller: emailController,
                label: 'Email Address',
                hint: 'Enter email address',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),

              AnimatedButton(
                onTap: isLoading ? () {} : _sendResetLink,
                child: Container(
                  height: 52,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: kDarkGreen,
                  ),
                  alignment: Alignment.center,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Send Reset Link',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

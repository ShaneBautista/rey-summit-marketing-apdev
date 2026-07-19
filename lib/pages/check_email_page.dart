import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/colors.dart';
import '../widgets/animated_button.dart';

/// Shown right after "Send Reset Link" on the Forgot Password screen.
///
/// Note: Firebase's password reset only supports an emailed link, not an
/// in-app 4-digit code — clicking the link opens Firebase's own hosted
/// reset page outside this app. So this screen mirrors the "Verification"
/// step visually (icon, headline, resend option) but tells the user to
/// check their inbox rather than asking them to type a code, since there
/// is no code to type.
class CheckEmailPage extends StatefulWidget {
  final String email;

  const CheckEmailPage({super.key, required this.email});

  @override
  State<CheckEmailPage> createState() => _CheckEmailPageState();
}

class _CheckEmailPageState extends State<CheckEmailPage> {
  final AuthService _authService = AuthService();
  bool isResending = false;
  String? resendMessage;

  Future<void> _resend() async {
    setState(() {
      isResending = true;
      resendMessage = null;
    });
    try {
      await _authService.sendPasswordResetEmail(widget.email);
      if (!mounted) return;
      setState(() => resendMessage = 'Reset link sent again.');
    } catch (e) {
      if (!mounted) return;
      setState(() => resendMessage = 'Could not resend — try again shortly.');
    } finally {
      if (mounted) setState(() => isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLightMint,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 140,
                width: 140,
                decoration: BoxDecoration(
                  color: kHeaderGreen.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_email_read_outlined,
                    size: 68, color: kDarkGreen),
              ),
              const SizedBox(height: 28),
              const Text(
                'Check your email',
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: kDarkGreen),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'We sent a password reset link to\n${widget.email}\n'
                'Open it on this device to set a new password.',
                style: const TextStyle(fontSize: 14, color: kFieldGrey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),

              AnimatedButton(
                onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: Container(
                  height: 52,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: kDarkGreen,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Back to Login',
                    style: TextStyle(
                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              GestureDetector(
                onTap: isResending ? null : _resend,
                child: Text(
                  isResending ? 'Resending...' : "Didn't get it? Resend link",
                  style: const TextStyle(
                      color: kDarkGreen, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              if (resendMessage != null) ...[
                const SizedBox(height: 10),
                Text(resendMessage!,
                    style: const TextStyle(color: kFieldGrey, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

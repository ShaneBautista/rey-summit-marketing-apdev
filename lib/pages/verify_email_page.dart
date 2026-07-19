import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/colors.dart';
import '../widgets/animated_button.dart';
import '../routing.dart';

/// Shown right after sign-up. Firebase has already emailed a verification
/// link to [email]; this screen waits for the user to click it, with a
/// "Resend link" fallback and a "Continue" button that re-checks status.
///
/// Also auto-checks verification status whenever the app comes back to the
/// foreground (e.g. the user switches back from their email app/tab after
/// tapping the link), so they don't always have to tap "Continue" manually.
class VerifyEmailPage extends StatefulWidget {
  final String email;

  const VerifyEmailPage({super.key, required this.email});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage>
    with WidgetsBindingObserver {
  final AuthService _authService = AuthService();

  bool isChecking = false;
  bool isResending = false;
  String? resendMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Fires when the user backgrounds/foregrounds the app — e.g. they leave
    // to open their email client, tap the verification link, then come
    // back. We only care about the "came back" transition.
    if (state == AppLifecycleState.resumed) {
      _checkVerified(silent: true);
    }
  }

  /// [silent] suppresses the "not verified yet" SnackBar — used for the
  /// automatic lifecycle-triggered check, so the user isn't nagged just for
  /// switching tabs/apps without having clicked the link yet. The manual
  /// button tap still shows the SnackBar via [silent] = false.
  Future<void> _checkVerified({bool silent = false}) async {
    if (isChecking) return; // avoid overlapping checks
    setState(() => isChecking = true);
    final verified = await _authService.isEmailVerified();
    if (!mounted) return;
    setState(() => isChecking = false);

    if (verified) {
      await routeToRoleHome(context);
    } else if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Not verified yet — check your inbox and tap the link.")),
      );
    }
  }

  Future<void> _resendLink() async {
    setState(() {
      isResending = true;
      resendMessage = null;
    });
    try {
      await _authService.sendEmailVerification();
      if (!mounted) return;
      setState(() => resendMessage = 'Verification link resent.');
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
                child: const Icon(Icons.mark_email_read_outlined, size: 68, color: kDarkGreen),
              ),
              const SizedBox(height: 28),
              const Text(
                'Verify your email',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kDarkGreen),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'We sent a verification link to\n${widget.email}',
                style: const TextStyle(fontSize: 14, color: kFieldGrey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),

              AnimatedButton(
                onTap: isChecking ? () {} : () => _checkVerified(silent: false),
                child: Container(
                  height: 52,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: kDarkGreen,
                  ),
                  alignment: Alignment.center,
                  child: isChecking
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          "I've verified — Continue",
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              GestureDetector(
                onTap: isResending ? null : _resendLink,
                child: Text(
                  isResending ? 'Resending...' : "Didn't receive it? Resend link",
                  style: const TextStyle(color: kDarkGreen, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              if (resendMessage != null) ...[
                const SizedBox(height: 10),
                Text(resendMessage!, style: const TextStyle(color: kFieldGrey, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

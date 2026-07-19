import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../widgets/animated_button.dart';
import 'homepage.dart';
import 'signup_page.dart';

/// Landing screen — logo, tagline, and the choice to sign up or log in.
/// This is the first thing a user sees before any auth screen.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLightMint,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Image.asset('assets/images/logo.png', height: 70),
              const Spacer(flex: 2),
              const Text(
                'Welcome!',
                style: TextStyle(
                  color: kDarkGreen,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Login or sign up to continue',
                style: TextStyle(color: kFieldGrey, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),
              AnimatedButton(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SignUpPage()),
                  );
                },
                child: Container(
                  height: 52,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: kDarkGreen,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Create Account',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              AnimatedButton(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const Homepage()),
                  );
                },
                child: Container(
                  height: 52,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border.all(color: kDarkGreen, width: 1.4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Already have an account',
                    style: TextStyle(
                      color: kDarkGreen,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

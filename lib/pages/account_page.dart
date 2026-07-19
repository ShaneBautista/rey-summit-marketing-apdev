import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../theme/colors.dart';
import '../widgets/animated_button.dart';
import 'welcome_page.dart';

/// Account tab — shows the signed-in user's profile info (pulled from
/// Firestore via AuthService.fetchCurrentUserProfile) and a sign-out button.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final AuthService _authService = AuthService();
  late Future<AppUserModel?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _authService.fetchCurrentUserProfile();
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomePage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppUserModel?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kDarkGreen));
        }
        final profile = snapshot.data;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('My Account',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kDarkGreen)),
              const SizedBox(height: 24),
              Center(
                child: Container(
                  height: 84,
                  width: 84,
                  decoration: BoxDecoration(color: kHeaderGreen.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.person, color: kDarkGreen, size: 40),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  profile != null ? '${profile.firstName} ${profile.lastName}' : 'Your Account',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kDarkGreen),
                ),
              ),
              if (profile != null) ...[
                const SizedBox(height: 4),
                Center(child: Text(profile.email, style: const TextStyle(color: kFieldGrey, fontSize: 13))),
              ],
              const SizedBox(height: 32),
              AnimatedButton(
                onTap: _signOut,
                child: Container(
                  height: 52,
                  width: double.infinity,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: kDarkGreen),
                  alignment: Alignment.center,
                  child: const Text('Sign Out',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import 'admin/admin_shell.dart';
import 'models/user_model.dart';
import 'pages/home_dashboard_page.dart';
import 'services/auth_service.dart';

/// Fetches the signed-in user's profile and pushes them into the right
/// app: [AdminShell] for `UserRole.employee`, [HomeDashboardPage] for
/// `UserRole.customer`. Call this right after login succeeds and email
/// is verified — see homepage.dart and verify_email_page.dart.
Future<void> routeToRoleHome(BuildContext context) async {
  final profile = await AuthService().fetchCurrentUserProfile();

  if (!context.mounted) return;

  final destination = profile?.role == UserRole.employee ? const AdminShell() : const HomeDashboardPage();

  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => destination),
    (route) => false,
  );
}

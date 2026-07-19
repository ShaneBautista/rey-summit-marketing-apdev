import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/colors.dart';
import '../widgets/animated_button.dart';
import '../widgets/app_field.dart';
import '../routing.dart';
import '../utils/validators.dart';
import 'forgot_password_page.dart';
import 'signup_page.dart';
import 'verify_email_page.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  bool keepLoggedIn = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);
    try {
      await _authService.login(
        email: emailController.text,
        password: passwordController.text,
      );
      if (!mounted) return;

      final verified = await _authService.isEmailVerified();
      if (!mounted) return;

      if (!verified) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyEmailPage(email: emailController.text.trim()),
          ),
        );
        return;
      }

      await routeToRoleHome(context);
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? 'Login failed.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLightMint,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Row(
                  children: [
                    Icon(Icons.arrow_back, color: kDarkGreen, size: 18),
                    SizedBox(width: 6),
                    Text('Back', style: TextStyle(color: kDarkGreen, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Center(child: Image.asset('assets/images/logo.png', height: 50)),
              const SizedBox(height: 28),
              const Text(
                'Login Account',
                style: TextStyle(color: kDarkGreen, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Welcome back!',
                style: TextStyle(color: kFieldGrey, fontSize: 14),
              ),
              const SizedBox(height: 28),

              AppField(
                controller: emailController,
                label: 'Email Address',
                hint: 'Enter email address',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: Validators.email,
                textInputAction: TextInputAction.next,
              ),
              AppField(
                controller: passwordController,
                label: 'Password',
                hint: 'Enter password',
                icon: Icons.lock_outline,
                obscure: true,
                validator: (v) => Validators.required(v, label: 'Password'),
                textInputAction: TextInputAction.done,
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => keepLoggedIn = !keepLoggedIn),
                    child: Row(
                      children: [
                        SizedBox(
                          height: 20,
                          width: 20,
                          child: Checkbox(
                            value: keepLoggedIn,
                            activeColor: kDarkGreen,
                            onChanged: (v) => setState(() => keepLoggedIn = v ?? false),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('Keep me logged in',
                            style: TextStyle(color: kFieldGrey, fontSize: 13)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                      );
                    },
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(color: kDarkGreen, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),

              AnimatedButton(
                onTap: isLoading ? () {} : _login,
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
                          'Login',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 26),

              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('Or login with', style: TextStyle(color: kFieldGrey, fontSize: 12)),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedButton(
                    onTap: () => _showMessage(
                        'Facebook login isn\'t wired up yet — needs the flutter_facebook_auth package.'),
                    child: _socialCircle(const Icon(Icons.facebook, color: Color(0xFF1877F2), size: 26)),
                  ),
                  const SizedBox(width: 24),
                  AnimatedButton(
                    onTap: () =>
                        _showMessage('Google login isn\'t wired up yet — needs the google_sign_in package.'),
                    child: _socialCircle(const Text('G',
                        style: TextStyle(color: Color(0xFFDB4437), fontSize: 22, fontWeight: FontWeight.bold))),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? ", style: TextStyle(color: kFieldGrey, fontSize: 13)),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignUpPage()),
                      );
                    },
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(color: kDarkGreen, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          )),
        ),
      ),
    );
  }

  Widget _socialCircle(Widget child) {
    return Container(
      height: 50,
      width: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [BoxShadow(color: kShadowColor, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Center(child: child),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/colors.dart';
import '../widgets/animated_button.dart';
import '../widgets/app_field.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../utils/validators.dart';
import 'verify_email_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  UserRole selectedRole = UserRole.customer;
  bool agreedToPolicy = false;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final phoneController = TextEditingController();

  final employeeIdController = TextEditingController();

  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    employeeIdController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!agreedToPolicy) {
      _showMessage('Please agree to the privacy policy to continue.');
      return;
    }
    if (passwordController.text != confirmController.text) {
      _showMessage("Passwords don't match");
      return;
    }

    setState(() => isLoading = true);
    try {
      await _authService.register(
        email: emailController.text,
        password: passwordController.text,
        firstName: firstNameController.text,
        lastName: lastNameController.text,
        phoneNumber: phoneController.text,
        role: selectedRole,
        employeeId: selectedRole == UserRole.employee ? employeeIdController.text : null,
      );

      if (!mounted) return;
      // Fire off the verification email now that the account exists.
      await _authService.sendEmailVerification();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyEmailPage(email: emailController.text.trim()),
        ),
      );
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? 'Sign up failed');
    } catch (e) {
      debugPrint('Sign up failed (non-auth error): $e');
      _showMessage('Sign up failed: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _roleToggle() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderGrey),
        boxShadow: const [BoxShadow(color: kShadowColor, blurRadius: 12, offset: Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Expanded(child: _roleButton('Customer', UserRole.customer)),
          Expanded(child: _roleButton('Employee', UserRole.employee)),
        ],
      ),
    );
  }

  Widget _roleButton(String label, UserRole role) {
    final bool selected = selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => selectedRole = role),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? kDarkGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : kFieldGrey,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
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
              const SizedBox(height: 24),
              const Text(
                'Create Account',
                style: TextStyle(color: kDarkGreen, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sign up to continue',
                style: TextStyle(color: kFieldGrey, fontSize: 14),
              ),
              const SizedBox(height: 24),

              _roleToggle(),

              AppField(
                controller: firstNameController,
                label: 'First Name',
                hint: 'Enter first name',
                icon: Icons.person_outline,
                validator: (v) => Validators.required(v, label: 'First name'),
                textInputAction: TextInputAction.next,
              ),
              AppField(
                controller: lastNameController,
                label: 'Last Name',
                hint: 'Enter last name',
                icon: Icons.person_outline,
                validator: (v) => Validators.required(v, label: 'Last name'),
                textInputAction: TextInputAction.next,
              ),
              AppField(
                controller: phoneController,
                label: 'Mobile Number',
                hint: 'Enter mobile number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: Validators.phone,
                textInputAction: TextInputAction.next,
              ),

              // Position and Department were removed — an employee's role
              // within the company is managed separately by an admin, not
              // self-reported at signup. Employee ID is kept since it's
              // used to look the person up / verify they're on staff.
              if (selectedRole == UserRole.employee) ...[
                AppField(
                  controller: employeeIdController,
                  label: 'Employee ID',
                  hint: 'Enter employee ID',
                  icon: Icons.badge_outlined,
                  validator: (v) => Validators.required(v, label: 'Employee ID'),
                  textInputAction: TextInputAction.next,
                ),
              ],

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
                hint: 'Create password',
                icon: Icons.lock_outline,
                obscure: true,
                validator: (v) => Validators.minLength(v, 6, label: 'Password'),
                textInputAction: TextInputAction.next,
              ),
              AppField(
                controller: confirmController,
                label: 'Confirm Password',
                hint: 'Re-enter password',
                icon: Icons.lock_outline,
                obscure: true,
                validator: (v) => Validators.matches(v, passwordController.text, label: 'Passwords'),
                textInputAction: TextInputAction.done,
              ),

              GestureDetector(
                onTap: () => setState(() => agreedToPolicy = !agreedToPolicy),
                child: Row(
                  children: [
                    SizedBox(
                      height: 20,
                      width: 20,
                      child: Checkbox(
                        value: agreedToPolicy,
                        activeColor: kDarkGreen,
                        onChanged: (v) => setState(() => agreedToPolicy = v ?? false),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text('I agree with the privacy policy',
                          style: TextStyle(color: kFieldGrey, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              AnimatedButton(
                onTap: isLoading ? () {} : _register,
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
                          'Sign Up',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('Or sign up with', style: TextStyle(color: kFieldGrey, fontSize: 12)),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedButton(
                    onTap: () => _showMessage('Google sign-up isn\'t wired up yet — needs the google_sign_in package.'),
                    child: _socialCircle(
                      const Text('G',
                          style: TextStyle(color: Color(0xFFDB4437), fontSize: 22, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 24),
                  AnimatedButton(
                    onTap: () => _showMessage('Facebook sign-up isn\'t wired up yet — needs the flutter_facebook_auth package.'),
                    child: _socialCircle(
                      const Icon(Icons.facebook, color: Color(0xFF1877F2), size: 26),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account? ', style: TextStyle(color: kFieldGrey, fontSize: 13)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      'Login',
                      style: TextStyle(color: kDarkGreen, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
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

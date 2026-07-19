/// Shared form validators — reused by any TextFormField across the app
/// via AppField's `validator` parameter. Keeping these in one place means
/// "what counts as a valid email" only has to be decided once.
class Validators {
  Validators._();

  static String? required(String? value, {String label = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final pattern = RegExp(r'^[\w\.\-\+]+@[\w\-]+\.[\w\-\.]+$');
    if (!pattern.hasMatch(value.trim())) return 'Enter a valid email address';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Phone number is required';
    final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length < 7) return 'Enter a valid phone number';
    return null;
  }

  static String? minLength(String? value, int length, {String label = 'This field'}) {
    if (value == null || value.isEmpty) return '$label is required';
    if (value.length < length) return '$label must be at least $length characters';
    return null;
  }

  /// Cross-field check — pass the other controller's current text in.
  static String? matches(String? value, String other, {String label = 'Fields'}) {
    if (value != other) return "$label don't match";
    return null;
  }
}

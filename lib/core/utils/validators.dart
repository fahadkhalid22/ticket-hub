class Validators {
  static String? requiredText(String? value, {String label = 'This field'}) => value == null || value.trim().isEmpty ? '$label is required' : null;
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim()) ? null : 'Enter a valid email';
  }
  static String? password(String? value) => value == null || value.length < 8 ? 'Use at least 8 characters' : null;
  static String? positiveInt(String? value) {
    final n = int.tryParse(value ?? '');
    return n == null || n <= 0 ? 'Enter a number greater than zero' : null;
  }
}

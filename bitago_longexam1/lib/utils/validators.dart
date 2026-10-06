class Validators {
  static String? requiredText(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;
  static String? name(String? value) =>
      requiredText(value) ??
      (value!.trim().length > 80 ? 'Use at most 80 characters.' : null);
  static String? username(String? value) =>
      RegExp(r'^[a-zA-Z0-9_.]{3,30}$').hasMatch(value?.trim() ?? '')
      ? null
      : 'Use 3–30 letters, numbers, dots or underscores.';
  static String? email(String? value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value?.trim() ?? '')
      ? null
      : 'Enter a valid email address.';
  static String? age(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    return number == null || number < 1 || number > 150
        ? 'Enter an age from 1 to 150.'
        : null;
  }

  static String? contactNo(String? value) =>
      RegExp(r'^\+?[0-9 ()-]{7,20}$').hasMatch(value?.trim() ?? '') &&
          (value ?? '').replaceAll(RegExp(r'\D'), '').length >= 7
      ? null
      : 'Enter a valid contact number.';
  static String? password(String? value) =>
      value != null &&
          value.length >= 8 &&
          value.length <= 128 &&
          RegExp(r'[A-Za-z]').hasMatch(value) &&
          RegExp(r'[0-9]').hasMatch(value)
      ? null
      : 'Use 8–128 characters with a letter and a number.';
}

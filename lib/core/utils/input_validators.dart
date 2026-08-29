class InputValidators {
  static String? validateTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Title cannot be empty';
    }
    if (value.length > 100) {
      return 'Title is too long (max 100 characters)';
    }
    return null;
  }

  static String? validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Amount cannot be empty';
    }
    final amount = double.tryParse(value);
    if (amount == null) {
      return 'Invalid number format';
    }
    if (amount <= 0) {
      return 'Amount must be greater than zero';
    }
    return null;
  }



  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name cannot be empty';
    }
    if (value.length > 50) {
      return 'Name is too long (max 50 characters)';
    }
    return null;
  }

  static String? validateUpiId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    if (!value.contains('@')) {
      return 'Invalid UPI ID format (must contain @)';
    }
    return null;
  }

  static String? validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final cleanNum = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanNum.length != 10) {
      return 'Phone number must be exactly 10 digits';
    }
    return null;
  }
}

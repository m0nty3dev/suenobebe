import 'package:flutter/material.dart';

void showSuccessSnackbar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: const Color(0xFF6BAA75),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

void showErrorSnackbar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: const Color(0xFFD96B6B),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

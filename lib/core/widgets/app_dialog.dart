import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

Future<bool?> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
  String cancelLabel = 'Cancelar',
  bool destructive = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: destructive
              ? TextButton.styleFrom(foregroundColor: AppColors.errorColor)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

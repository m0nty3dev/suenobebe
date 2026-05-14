import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.outlined = false,
    this.icon,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool outlined;
  final Widget? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.onPrimaryLight),
          )
        : icon != null
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [icon!, const SizedBox(width: 8), Text(label)],
              )
            : Text(label);

    if (outlined) {
      return OutlinedButton(
        onPressed: loading ? null : onPressed,
        child: child,
      );
    }
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: color != null
          ? ElevatedButton.styleFrom(backgroundColor: color)
          : null,
      child: child,
    );
  }
}

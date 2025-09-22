// widgets/custom_button.dart
import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final Color? buttonColor;
  final Color? textColor;
  // Removed padding and textStyle parameters as per previous discussion,
  // assuming CustomButton now manages its internal padding and text style.
  // If you re-added them for specific reasons, they should be here.

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.buttonColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null && !isLoading;

    return ElevatedButton(
      onPressed: isEnabled ? onPressed : null,
      style: ElevatedButton.styleFrom(
        // Set a default minimum size for consistency, but allow it to shrink if needed by children
        // The double.infinity will make it expand to parent width if not otherwise constrained.
        minimumSize: const Size(double.infinity, 54),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0), // Use fixed padding, or add it back as a parameter if needed
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: isEnabled
            ? (buttonColor ?? Theme.of(context).primaryColor)
            : (buttonColor ?? Theme.of(context).primaryColor).withOpacity(0.5),
        foregroundColor: isEnabled
            ? (textColor ?? Colors.white)
            : (textColor ?? Colors.white).withOpacity(0.7),
        elevation: isEnabled ? 4 : 0,
        shadowColor: (buttonColor ?? Theme.of(context).primaryColor).withOpacity(0.4),
      ),
      child: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              // mainAxisSize: MainAxisSize.min, // Keep this if you want the button to generally shrink to fit content
                                                 // However, if the ElevatedButton's minimumSize or parent width forces it
                                                 // to be wide, the Row will also become wide.
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 22),
                  const SizedBox(width: 8),
                ],
                // Wrap the Text widget with Expanded to ensure it takes only the available space
                Expanded( // <--- THIS IS THE KEY CHANGE
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: icon != null ? TextAlign.left : TextAlign.center, // Adjust text alignment based on icon presence
                    overflow: TextOverflow.ellipsis, // Add ellipsis if text is too long
                    maxLines: 1, // Ensure text stays on a single line
                  ),
                ),
              ],
            ),
    );
  }
}
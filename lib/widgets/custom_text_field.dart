// widgets/custom_text_field.dart
import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? hintText;
  final int? maxLines;
  final Widget? suffixIcon;
  final bool enabled;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final EdgeInsetsGeometry? contentPadding;
  final Widget? prefixIcon;
  final bool readOnly; 

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.hintText,
    this.maxLines = 1,
    this.suffixIcon,
    this.enabled = true,
    this.validator,
    this.onChanged,
    this.contentPadding,
    this.prefixIcon, 
    this.readOnly = false, 
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      validator: validator,
      onChanged: onChanged,
      readOnly: readOnly, 
      style: TextStyle(
        color: enabled ? Colors.grey[800] : Colors.grey[600],
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        labelStyle: TextStyle(
          color: enabled ? Colors.grey[600] : Colors.grey[500],
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: enabled ? Colors.grey[400] : Colors.grey[300],
          fontStyle: FontStyle.italic,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 2.0,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: const BorderSide(color: Colors.red, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: const BorderSide(color: Colors.red, width: 2.0),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[100],
        suffixIcon: suffixIcon,
 
        contentPadding: contentPadding ?? const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        prefixIcon: prefixIcon, 
      ),
    );
  }
}
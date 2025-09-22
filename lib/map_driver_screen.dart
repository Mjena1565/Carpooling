// TODO Implement this library.
import 'package:flutter/material.dart';

class MapDriverScreen extends StatelessWidget {
  final String title;
  final String responseData;
  final bool isRideLater;

  const MapDriverScreen({
    super.key,
    required this.title,
    required this.responseData,
    required this.isRideLater,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: const Center(
        child: Text(
          "Dummy Map Screen",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
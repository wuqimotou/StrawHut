import 'package:flutter/material.dart';

/// 阅读器界面
class ReaderScreen extends StatelessWidget {
  const ReaderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reader')),
      body: const Center(child: Text('Reader Screen')),
    );
  }
}

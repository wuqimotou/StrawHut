import 'package:flutter/material.dart';

/// 编辑器界面
class EditorScreen extends StatelessWidget {
  const EditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editor')),
      body: const Center(child: Text('Editor Screen')),
    );
  }
}

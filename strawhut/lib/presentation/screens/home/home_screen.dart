import 'package:flutter/material.dart';

/// 首页界面
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('StrawHut')),
      body: const Center(child: Text('Home Screen')),
    );
  }
}

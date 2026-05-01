import 'package:flutter/material.dart';

/// 发布对话框
class PublishDialog extends StatelessWidget {
  const PublishDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const PublishDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

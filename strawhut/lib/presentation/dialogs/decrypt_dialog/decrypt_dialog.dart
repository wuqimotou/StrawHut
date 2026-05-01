import 'package:flutter/material.dart';

/// 解密对话框
class DecryptDialog extends StatelessWidget {
  const DecryptDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const DecryptDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

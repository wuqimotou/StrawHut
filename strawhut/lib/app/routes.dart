import 'package:flutter/material.dart';

/// 应用路由配置
class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String editor = '/editor';
  static const String reader = '/reader';

  static Map<String, WidgetBuilder> get routes => {
        home: (context) => const Scaffold(body: Center(child: Text('Home Screen'))),
        editor: (context) => const Scaffold(body: Center(child: Text('Editor Screen'))),
        reader: (context) => const Scaffold(body: Center(child: Text('Reader Screen'))),
      };
}

import 'package:flutter/material.dart';
import 'package:strawhut/app/theme.dart';
import 'package:strawhut/app/routes.dart';

/// StrawHut 应用主组件
class StrawHutApp extends StatelessWidget {
  const StrawHutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StrawHut',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: AppRoutes.home,
      routes: AppRoutes.routes,
    );
  }
}

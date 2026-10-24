import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'theme/app_theme.dart';

class TcbApp extends StatelessWidget {
  const TcbApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TCB Live',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const HomeShell(),
    );
  }
}

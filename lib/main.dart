import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/app_state.dart';
import 'screens/main_shell.dart';

void main() {
  runApp(ChangeNotifierProvider(create: (_) => AppState(), child: const App()));
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'YouTube 精听',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF3EBDD),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7B6048),
          primary: const Color(0xFF6E5139),
          secondary: const Color(0xFF9A8764),
          surface: const Color(0xFFFFFAF1),
        ),
        fontFamily: 'Roboto',
      ),
      home: const MainShell(),
    );
  }
}

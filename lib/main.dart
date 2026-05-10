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
      themeMode: ThemeMode.system,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: const MainShell(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? const Color(0xFFD8BE94) : const Color(0xFF6E5139),
      onPrimary: isDark ? const Color(0xFF2A1F17) : const Color(0xFFFFFAF1),
      secondary: isDark ? const Color(0xFFC8B38B) : const Color(0xFF9A8764),
      onSecondary: isDark ? const Color(0xFF2A1F17) : const Color(0xFFFFFAF1),
      error: isDark ? const Color(0xFFFFB4A9) : const Color(0xFFB25B4F),
      onError: isDark ? const Color(0xFF561E18) : const Color(0xFFFFFAF1),
      errorContainer: isDark ? const Color(0xFF5B2A24) : const Color(0xFFF4D8D2),
      onErrorContainer:
          isDark ? const Color(0xFFFFDAD4) : const Color(0xFF6D2B23),
      surface: isDark ? const Color(0xFF221B15) : const Color(0xFFFFFAF1),
      onSurface: isDark ? const Color(0xFFF2E7D7) : const Color(0xFF3C2C20),
      surfaceContainerHighest:
          isDark ? const Color(0xFF3B3026) : const Color(0xFFE3D6C2),
      onSurfaceVariant:
          isDark ? const Color(0xFFD9C7AF) : const Color(0xFF6E5139),
      outline: isDark ? const Color(0xFF6A5746) : const Color(0xFFD0BEA7),
      outlineVariant:
          isDark ? const Color(0xFF3B3026) : const Color(0xFFE1D3BE),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface:
          isDark ? const Color(0xFFF3EBDD) : const Color(0xFF33271F),
      onInverseSurface:
          isDark ? const Color(0xFF33271F) : const Color(0xFFF3EBDD),
      inversePrimary:
          isDark ? const Color(0xFF6E5139) : const Color(0xFFD8BE94),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF15110D) : const Color(0xFFF3EBDD),
      colorScheme: scheme,
      fontFamily: 'Roboto',
    );
  }
}

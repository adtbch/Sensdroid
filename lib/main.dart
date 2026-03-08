import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensdroid/views/pages/main_navigation.dart';
import 'package:sensdroid/viewmodels/sensor_viewmodel.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SensdroidApp());
}

class SensdroidApp extends StatelessWidget {
  const SensdroidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SensorViewModel()),
      ],
      child: MaterialApp(
        title: 'Sensdroid',
        debugShowCheckedModeBanner: false,
        theme: _buildLightTheme(),
        darkTheme: _buildDarkTheme(),
        themeMode: ThemeMode.dark,
        home: const MainNavigation(),
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1A1A1A),
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF00D9FF), // Bright cyan
        secondary: Color(0xFF0091EA), // Deep blue accent
        tertiary: Color(0xFF00E5FF), // Light cyan
        surface: Color(0xFF0A1929), // Deep blue-black
        surfaceContainerHighest: Color(0xFF143A52),
        onSurface: Color(0xFFE0F7FF),
        error: Color(0xFFFF6B9D),
      ),
      scaffoldBackgroundColor: const Color(0xFF001E2F),
      cardTheme: CardThemeData(
        color: const Color(0xFF0A1929).withOpacity(0.6),
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          side: BorderSide(
            color: const Color(0xFF00D9FF).withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF0A1929).withOpacity(0.8),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
          color: Color(0xFF00D9FF),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00D9FF),
          foregroundColor: const Color(0xFF001E2F),
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          color: Color(0xFFE0E0E0),
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Color(0xFFE0E0E0),
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
          color: Color(0xFFE0E0E0),
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: Color(0xFFB0B0B0),
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: Color(0xFF909090),
        ),
      ),
      iconTheme: const IconThemeData(
        color: Color(0xFF00D9FF),
        size: 24,
      ),
    );
  }
}

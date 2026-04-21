import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
      providers: [ChangeNotifierProvider(create: (_) => SensorViewModel())],
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
      textTheme: GoogleFonts.interTextTheme(),
    );
  }

  ThemeData _buildDarkTheme() {
    final base = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF00D9FF), // Vivid cyan
        secondary: Color(0xFF7C4DFF), // Rich purple-violet
        tertiary: Color(0xFF00E5B0), // Teal-green
        surface: Color(0xFF07111A), // Near-black deep blue
        surfaceContainerHighest: Color(0xFF10253A),
        surfaceContainerHigh: Color(0xFF0D1F30),
        surfaceContainer: Color(0xFF0A1929),
        onSurface: Color(0xFFE4F0F8),
        onSurfaceVariant: Color(0xFF7BA7BF),
        outline: Color(0xFF2A4A60),
        outlineVariant: Color(0xFF1A3347),
        error: Color(0xFFFF6B9D),
        errorContainer: Color(0xFF3D0020),
        onErrorContainer: Color(0xFFFFB3CE),
        primaryContainer: Color(0xFF00374A),
        onPrimaryContainer: Color(0xFFB3F0FF),
        secondaryContainer: Color(0xFF1E0A5A),
        onSecondaryContainer: Color(0xFFCBB8FF),
        tertiaryContainer: Color(0xFF003828),
        onTertiaryContainer: Color(0xFFB3FFE8),
      ),
      scaffoldBackgroundColor: const Color(0xFF07111A),
      cardTheme: CardThemeData(
        color: const Color(0xFF0A1929).withOpacity(0.7),
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          side: BorderSide(
            color: const Color(0xFF00D9FF).withOpacity(0.15),
            width: 1,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF07111A),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: const Color(0xFFE4F0F8),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF00D9FF)),
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
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF00D9FF),
          foregroundColor: const Color(0xFF001E2F),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0A1929),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2A4A60)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2A4A60)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00D9FF), width: 1.5),
        ),
        labelStyle: const TextStyle(color: Color(0xFF7BA7BF)),
      ),
      textTheme: base.copyWith(
        headlineLarge: base.headlineLarge?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
          color: const Color(0xFFE4F0F8),
        ),
        headlineMedium: base.headlineMedium?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: const Color(0xFFE4F0F8),
        ),
        titleLarge: base.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFE4F0F8),
        ),
        titleMedium: base.titleMedium?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFE4F0F8),
        ),
        bodyLarge: base.bodyLarge?.copyWith(
          fontSize: 15,
          color: const Color(0xFFB8D4E0),
        ),
        bodyMedium: base.bodyMedium?.copyWith(
          fontSize: 13,
          color: const Color(0xFF7BA7BF),
        ),
        labelLarge: base.labelLarge?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      iconTheme: const IconThemeData(color: Color(0xFF00D9FF), size: 22),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: const Color(0xFF00D9FF).withOpacity(0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF00D9FF),
            );
          }
          return GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF7BA7BF),
          );
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF001E2F);
          }
          return const Color(0xFF7BA7BF);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF00D9FF);
          }
          return const Color(0xFF2A4A60);
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: const Color(0xFF00D9FF),
        inactiveTrackColor: const Color(0xFF2A4A60),
        thumbColor: const Color(0xFF00D9FF),
        overlayColor: const Color(0xFF00D9FF).withOpacity(0.15),
        trackHeight: 4,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF1A3347),
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF0A1929),
        selectedColor: const Color(0xFF00374A),
        side: const BorderSide(color: Color(0xFF2A4A60)),
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }
}

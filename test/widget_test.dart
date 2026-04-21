// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:sensdroid/viewmodels/sensor_viewmodel.dart';
import 'package:sensdroid/views/pages/main_navigation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Sensdroid app smoke test', (WidgetTester tester) async {
    // Use a larger viewport so sliver headers render without test-time overflow.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Build a lightweight app shell with test-safe viewmodel config.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SensorViewModel(autoDetectSensors: false),
        child: const MaterialApp(home: MainNavigation()),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));

    // Verify the dashboard hero title is rendered.
    expect(find.text('USB Serial Control'), findsOneWidget);
  });
}

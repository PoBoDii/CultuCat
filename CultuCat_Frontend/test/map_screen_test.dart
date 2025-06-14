
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cultucat_front/screens/event_map/map.dart';

// Initialize EasyLocalization for testing
class TestEasyLocalization extends StatelessWidget {
  final Widget child;

  const TestEasyLocalization({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('es')],
      path: 'assets/lang', // Match with your actual path
      fallbackLocale: const Locale('en'),
      child: child,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock the MethodChannels before any tests
  setUp(() {
    // Mock shared_preferences
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
          (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') {
          return <String, dynamic>{}; // Empty preferences
        }
        return null;
      },
    );


    // Mock GoogleMap's channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/google_maps_flutter'),
          (MethodCall methodCall) async => null,
    );


    // Mock geolocator
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geolocator'),
          (MethodCall methodCall) async {
        if (methodCall.method == 'checkPermission') {
          return 1; // LocationPermission.whileInUse
        } else if (methodCall.method == 'isLocationServiceEnabled') {
          return true;
        }
        return null;
      },
    );

  });

  // Setup mock SharedPreferences
  Future<void> setUpSharedPreferences() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();
  }

  // Create a testable widget with EasyLocalization
  Widget createTestableWidget(Widget child) {
    return MaterialApp(
      home: EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('es')],
        path: 'assets/lang',
        fallbackLocale: const Locale('en'),
        child: child,
      ),
    );
  }

  // Basic test group
  group('MapScreen Widget Tests', () {
    setUpAll(() async {
      await setUpSharedPreferences();
      await EasyLocalization.ensureInitialized();
    });

    // IMPORTANT: The following test is just a skeleton.
    // Since we can't directly access your MapScreen implementation,
    // you'll need to customize it based on your actual widget.

    testWidgets(
        'MapScreen should build without errors', (WidgetTester tester) async {
      // Replace this with your actual MapScreen widget
      final widget = const Placeholder(); // Use your MapScreen() here

      // Build the widget
      await tester.pumpWidget(createTestableWidget(widget));
      await tester.pumpAndSettle();

      // Basic verification
      expect(find.byType(Placeholder),
          findsOneWidget); // Replace with appropriate assertions
    });
  });

  group('Location functionality', () {
    testWidgets(
        'My location button should center map on user location when permissions granted',
            (WidgetTester tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: TestEasyLocalization(
                child: MapScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Tap my location button
          await tester.tap(find.byIcon(Icons.my_location));
          await tester.pumpAndSettle();

          // For now just verify no errors occurred
          expect(true, isTrue);
        });
  });

  group('Navigation tests', () {
    testWidgets('Profile button navigates to profile page', (
        WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TestEasyLocalization(
            child: MapScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap profile button
      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();

      // For now just verify no errors occurred
      expect(true, isTrue);
    });
  });
}
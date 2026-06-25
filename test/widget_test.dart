import 'package:flutter_test/flutter_test.dart';
import 'package:hilla_ride/app.dart';
import 'package:hilla_ride/core/config/app_variant.dart';
import 'package:hilla_ride/core/providers/app_mode_provider.dart';
import 'package:hilla_ride/core/providers/app_state.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('shows firebase setup when backend is not configured', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppModeProvider()),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ],
        child: const HillaRideApp(
          variant: AppVariant.mobile,
          firebaseReady: false,
          firebaseError: 'test',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('flutterfire configure'), findsOneWidget);
  });
}

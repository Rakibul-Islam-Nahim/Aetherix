import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherix_app/app/app.dart';

void main() {
  testWidgets('Aetherix shell renders brand mark', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: AetherixApp()),
    );
    // Splash screen should show the brand.
    expect(find.text('AETHERIX'), findsOneWidget);
  });
}
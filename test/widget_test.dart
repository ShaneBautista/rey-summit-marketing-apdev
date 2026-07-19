import 'package:flutter_test/flutter_test.dart';

import 'package:test_for_apdev/main.dart';

void main() {
  testWidgets('app loads to login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Hello!'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}

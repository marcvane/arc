import 'package:flutter_test/flutter_test.dart';

import 'package:arc/main.dart';

void main() {
  testWidgets('ARC app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ArcApp());

    expect(find.text('ARC'), findsWidgets);
  });
}
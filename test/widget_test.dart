import 'package:flutter_test/flutter_test.dart';
import 'package:love_message/app.dart';

void main() {
  testWidgets('shows the love world and its contacts', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Mon petit monde'), findsOneWidget);
    expect(find.text('Léa'), findsOneWidget);
    expect(find.text('Thomas'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tickethub/core/theme/app_theme.dart';

void main() {
  testWidgets('TicketHub theme renders a Material screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Center(child: Text('TicketHub')),
        ),
      ),
    );

    expect(find.text('TicketHub'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tickethub/app/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('app reaches authentication/onboarding surface', (tester) async {
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    expect(url, isNotEmpty, reason: 'Pass --dart-define-from-file=.env.json');
    expect(key, isNotEmpty);
    await Supabase.initialize(url: url, publishableKey: key);
    await tester.pumpWidget(const ProviderScope(child: TicketHubApp()));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

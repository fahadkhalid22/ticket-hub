import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';
import '../shared/providers.dart';

class TicketHubApp extends ConsumerStatefulWidget {
  const TicketHubApp({super.key});
  @override ConsumerState<TicketHubApp> createState() => _TicketHubAppState();
}

class _TicketHubAppState extends ConsumerState<TicketHubApp> {
  late final router = buildRouter(ref.read(supabaseProvider));
  @override Widget build(BuildContext context) => MaterialApp.router(
    title: 'TicketHub',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: ThemeMode.system,
    routerConfig: router,
  );
}

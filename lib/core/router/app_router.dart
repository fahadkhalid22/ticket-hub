import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/admin/admin_screens.dart';
import '../../features/auth/auth_screens.dart';
import '../../features/booking/booking_screens.dart';
import '../../features/customer/customer_screens.dart';
import '../../features/owner/owner_screens.dart';
import '../../features/tickets/ticket_screen.dart';
import '../../shared/models/models.dart';
import '../../shared/repositories/ticket_hub_repository.dart';

GoRouter buildRouter(SupabaseClient client) {
  final repo = TicketHubRepository(client);
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      final path = state.uri.path;
      final public = path == '/login' || path == '/onboarding' || path.startsWith('/register');
      final user = client.auth.currentUser;
      if (user == null) {
        if (path == '/') return '/onboarding';
        return public ? null : '/login';
      }
      final profile = await repo.currentProfile();
      if (profile == null) return public ? null : '/login';
      if (public) return '/';
      if (path == '/') {
        return switch (profile.role) {
          UserRole.admin => '/admin/dashboard',
          UserRole.owner => '/owner/dashboard',
          UserRole.customer => '/home',
        };
      }
      if (path.startsWith('/admin') && profile.role != UserRole.admin) return '/forbidden';
      if (path.startsWith('/owner') && profile.role != UserRole.owner && profile.role != UserRole.admin) return '/forbidden';
      return null;
    },
    errorBuilder: (context, state) => Scaffold(body: Center(child: Text('Route error: ${state.error}'))),
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, state) => RegisterScreen(role: state.uri.queryParameters['role'] == 'owner' ? UserRole.owner : UserRole.customer)),
      GoRoute(path: '/forbidden', builder: (_, _) => const ForbiddenScreen()),

      GoRoute(path: '/home', builder: (_, _) => const CustomerHomeScreen()),
      GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
      GoRoute(path: '/category/:id', builder: (_, s) => CategoryScreen(id: s.pathParameters['id']!, name: s.uri.queryParameters['name'] ?? 'Category')),
      GoRoute(path: '/business/:id', builder: (_, s) => BusinessDetailsScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/listing/:id', builder: (_, s) => ListingDetailsScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/ticket-select/:scheduleId', builder: (_, s) => TicketSelectionScreen(scheduleId: s.pathParameters['scheduleId']!)),
      GoRoute(path: '/seat-select/:scheduleId', builder: (_, s) => SeatSelectionScreen(scheduleId: s.pathParameters['scheduleId']!)),
      GoRoute(path: '/checkout/:bookingId', builder: (_, s) => CheckoutScreen(bookingId: s.pathParameters['bookingId']!)),
      GoRoute(path: '/booking-confirmed/:bookingId', builder: (_, s) => BookingConfirmationScreen(bookingId: s.pathParameters['bookingId']!)),
      GoRoute(path: '/booking/:id', builder: (_, s) => BookingDetailsScreen(bookingId: s.pathParameters['id']!)),
      GoRoute(path: '/ticket/:id', builder: (_, s) => DigitalTicketScreen(ticketId: s.pathParameters['id']!)),
      GoRoute(path: '/my-tickets', builder: (_, _) => const MyTicketsScreen()),
      GoRoute(path: '/history', builder: (_, _) => const BookingHistoryScreen()),
      GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
      GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
      GoRoute(path: '/favorites', builder: (_, _) => const FavoritesScreen()),
      GoRoute(path: '/payments', builder: (_, _) => const PaymentsScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),

      GoRoute(path: '/owner/dashboard', builder: (_, _) => const OwnerDashboardScreen()),
      GoRoute(path: '/owner/register', builder: (_, _) => const BusinessRegistrationScreen()),
      GoRoute(path: '/owner/profile', builder: (_, _) => const OwnerProfileScreen()),
      GoRoute(path: '/owner/listings', builder: (_, _) => const OwnerListingsScreen()),
      GoRoute(path: '/owner/listing/new', builder: (_, _) => const ListingEditorScreen()),
      GoRoute(path: '/owner/listing/:id', builder: (_, s) => ListingEditorScreen(listingId: s.pathParameters['id']!)),
      GoRoute(path: '/owner/tickets/:listingId', builder: (_, s) => TicketManagementScreen(listingId: s.pathParameters['listingId']!)),
      GoRoute(path: '/owner/inventory', builder: (_, _) => const OwnerInventoryScreen()),
      GoRoute(path: '/owner/bookings', builder: (_, _) => const OwnerBookingsScreen()),
      GoRoute(path: '/owner/analytics', builder: (_, _) => const OwnerAnalyticsScreen()),
      GoRoute(path: '/owner/scanner', builder: (_, _) => const OwnerScannerScreen()),
      GoRoute(path: '/owner/settings', builder: (_, _) => const OwnerSettingsScreen()),

      GoRoute(path: '/admin/dashboard', builder: (_, _) => const AdminDashboardScreen()),
      GoRoute(path: '/admin/businesses', builder: (_, _) => const AdminBusinessesScreen()),
      GoRoute(path: '/admin/users', builder: (_, _) => const AdminUsersScreen()),
      GoRoute(path: '/admin/listings', builder: (_, _) => const AdminTableScreen(title: 'Listings', table: 'listings')),
      GoRoute(path: '/admin/tickets', builder: (_, _) => const AdminTableScreen(title: 'Tickets', table: 'tickets')),
      GoRoute(path: '/admin/bookings', builder: (_, _) => const AdminTableScreen(title: 'Bookings', table: 'bookings')),
      GoRoute(path: '/admin/payments', builder: (_, _) => const AdminTableScreen(title: 'Payments', table: 'payments')),
      GoRoute(path: '/admin/reviews', builder: (_, _) => const AdminReviewsScreen()),
      GoRoute(path: '/admin/categories', builder: (_, _) => const AdminCategoriesScreen()),
      GoRoute(path: '/admin/reports', builder: (_, _) => const AdminReportsScreen()),
      GoRoute(path: '/admin/settings', builder: (_, _) => const AdminSettingsScreen()),
      GoRoute(path: '/admin/audit', builder: (_, _) => const AdminTableScreen(title: 'Audit Log', table: 'audit_log')),
    ],
  );
}

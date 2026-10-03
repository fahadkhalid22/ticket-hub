import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/models.dart';
import 'payments/payment_provider.dart';
import 'repositories/ticket_hub_repository.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);
final repositoryProvider = Provider<TicketHubRepository>((ref) => TicketHubRepository(ref.watch(supabaseProvider)));
final paymentProvider = Provider<PaymentProvider>((ref) => SimulatedPaymentProvider());

final authChangesProvider = StreamProvider<AuthState>((ref) => ref.watch(supabaseProvider).auth.onAuthStateChange);
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  ref.watch(authChangesProvider);
  return ref.watch(repositoryProvider).currentProfile();
});
final categoriesProvider = FutureProvider<List<Category>>((ref) => ref.watch(repositoryProvider).categories());
final homeBusinessesProvider = FutureProvider<List<Business>>((ref) => ref.watch(repositoryProvider).businesses());
final featuredListingsProvider = FutureProvider<List<Listing>>((ref) => ref.watch(repositoryProvider).listings(featuredOnly: true));
final myBookingsProvider = FutureProvider<List<Booking>>((ref) => ref.watch(repositoryProvider).myBookings());
final myTicketsProvider = FutureProvider<List<DigitalTicket>>((ref) => ref.watch(repositoryProvider).myTickets());
final notificationsProvider = FutureProvider<List<AppNotification>>((ref) => ref.watch(repositoryProvider).notifications());
final favoriteIdsProvider = FutureProvider<List<String>>((ref) => ref.watch(repositoryProvider).favoriteBusinessIds());

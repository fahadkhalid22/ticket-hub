import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/common.dart';
import '../../shared/models/models.dart';
import '../../shared/providers.dart';

class TicketSelectionScreen extends ConsumerStatefulWidget {
  const TicketSelectionScreen({super.key, required this.scheduleId});
  final String scheduleId;

  @override
  ConsumerState<TicketSelectionScreen> createState() => _TicketSelectionState();
}

class _TicketSelectionState extends ConsumerState<TicketSelectionScreen> {
  final Map<String, int> quantities = {};
  bool busy = false;

  Future<void> _continue() async {
    if (quantities.values.fold<int>(0, (a, b) => a + b) == 0) return;
    setState(() => busy = true);
    try {
      final id = await ref.read(repositoryProvider).holdTickets(
            scheduleId: widget.scheduleId,
            quantities: quantities,
            seatIds: const [],
          );
      if (mounted) context.push('/checkout/$id');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Select Tickets',
      child: FutureBuilder<List<TicketType>>(
        future: ref.read(repositoryProvider).ticketTypes(widget.scheduleId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorState(message: '${snapshot.error}');
          }
          final types = snapshot.data ?? [];
          return Column(
            children: [
              Expanded(
                child: types.isEmpty
                    ? const EmptyState(message: 'No ticket types are available.')
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: types.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final type = types[index];
                          final count = quantities[type.id] ?? 0;
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          type.name,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(money(type.price)),
                                        Text(
                                          type.remaining <= 0
                                              ? 'Sold out'
                                              : '${type.remaining} remaining',
                                          style: TextStyle(
                                            color: type.remaining < 10 ? Colors.orange : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: count > 0
                                        ? () => setState(() => quantities[type.id] = count - 1)
                                        : null,
                                    icon: const Icon(Icons.remove_circle_outline),
                                  ),
                                  Text('$count', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  IconButton(
                                    onPressed: type.remaining > count
                                        ? () => setState(() => quantities[type.id] = count + 1)
                                        : null,
                                    icon: const Icon(Icons.add_circle_outline),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: const [BoxShadow(blurRadius: 14, color: Color(0x22000000))],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${quantities.values.fold<int>(0, (a, b) => a + b)} ticket(s)',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Expanded(
                        child: GradientButton(
                          label: 'Hold & Continue',
                          busy: busy,
                          onPressed: _continue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SeatSelectionScreen extends ConsumerStatefulWidget {
  const SeatSelectionScreen({super.key, required this.scheduleId});
  final String scheduleId;

  @override
  ConsumerState<SeatSelectionScreen> createState() => _SeatSelectionState();
}

class _SeatSelectionState extends ConsumerState<SeatSelectionScreen> {
  final Map<String, SeatAvailability> selected = {};
  bool busy = false;

  Future<void> _continue() async {
    if (selected.isEmpty) return;
    setState(() => busy = true);
    try {
      final quantities = <String, int>{};
      for (final seat in selected.values) {
        quantities[seat.ticketTypeId] = (quantities[seat.ticketTypeId] ?? 0) + 1;
      }
      final id = await ref.read(repositoryProvider).holdTickets(
            scheduleId: widget.scheduleId,
            quantities: quantities,
            seatIds: selected.values.map((e) => e.seatId).toList(),
          );
      if (mounted) context.push('/checkout/$id');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Select Seats',
      child: FutureBuilder<List<SeatAvailability>>(
        future: ref.read(repositoryProvider).seats(widget.scheduleId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return ErrorState(message: '${snapshot.error}');
          final seats = snapshot.data ?? [];
          if (seats.isEmpty) {
            return const EmptyState(message: 'This venue has no seat map configured.');
          }
          final rows = <String, List<SeatAvailability>>{};
          for (final seat in seats) {
            rows.putIfAbsent(seat.rowLabel, () => []).add(seat);
          }
          final total = selected.values.fold<double>(0, (sum, seat) => sum + seat.price);

          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(18),
                child: Column(
                  children: [
                    Text('STAGE / SCREEN', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 6),
                    Divider(indent: 60, endIndent: 60, thickness: 4),
                  ],
                ),
              ),
              const Wrap(
                spacing: 14,
                children: [
                  _Legend(Colors.green, 'Available'),
                  _Legend(Colors.deepPurple, 'Selected'),
                  _Legend(Colors.grey, 'Unavailable'),
                ],
              ),
              Expanded(
                child: InteractiveViewer(
                  minScale: .7,
                  maxScale: 3,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: rows.entries.map((row) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 28,
                              child: Text(row.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            ...row.value.map((seat) {
                              final isSelected = selected.containsKey(seat.seatId);
                              final available = seat.status == 'available';
                              return Tooltip(
                                message: '${seat.label} • ${money(seat.price)} • ${seat.status}',
                                child: GestureDetector(
                                  onTap: available
                                      ? () {
                                          setState(() {
                                            if (isSelected) {
                                              selected.remove(seat.seatId);
                                            } else {
                                              selected[seat.seatId] = seat;
                                            }
                                          });
                                        }
                                      : null,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    margin: const EdgeInsets.all(3),
                                    width: 34,
                                    height: 34,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.deepPurple
                                          : available
                                              ? Colors.green.withValues(alpha: .15)
                                              : Colors.grey.shade400,
                                      borderRadius: BorderRadius.circular(9),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.deepPurple
                                            : available
                                                ? Colors.green
                                                : Colors.grey,
                                      ),
                                    ),
                                    child: Text(
                                      seat.seatNumber,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isSelected ? Colors.white : null,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.surface,
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${selected.length} seat(s) • ${money(total)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: GradientButton(
                          label: 'Hold Seats',
                          busy: busy,
                          onPressed: _continue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label);
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 5),
        Text(label),
      ],
    );
  }
}

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutState();
}

class _CheckoutState extends ConsumerState<CheckoutScreen> {
  final formKey = GlobalKey<FormState>();
  final customerName = TextEditingController();
  final customerPhone = TextEditingController();
  final customerEmail = TextEditingController();
  String method = 'card';
  bool busy = false;
  Timer? timer;
  Duration remaining = Duration.zero;
  Booking? booking;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await ref.read(repositoryProvider).booking(widget.bookingId);
      if (!mounted) return;
      customerName.text = value.customerName;
      customerPhone.text = value.customerPhone ?? '';
      customerEmail.text = value.customerEmail ?? '';
      setState(() => booking = value);
      _tick();
      timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _tick() {
    final end = booking?.holdExpiresAt;
    if (end == null) return;
    final difference = end.difference(DateTime.now());
    if (mounted) {
      setState(() => remaining = difference.isNegative ? Duration.zero : difference);
    }
    if (difference.isNegative || difference == Duration.zero) timer?.cancel();
  }

  @override
  void dispose() {
    timer?.cancel();
    customerName.dispose();
    customerPhone.dispose();
    customerEmail.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (booking == null || remaining == Duration.zero) return;
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() => busy = true);
    try {
      await ref.read(repositoryProvider).updatePendingBookingContact(
            bookingId: booking!.id,
            customerName: customerName.text,
            customerPhone: customerPhone.text,
            customerEmail: customerEmail.text,
          );
      final payment = await ref.read(paymentProvider).charge(
            method: method,
            amount: booking!.totalAmount,
            bookingId: booking!.id,
          );
      await ref.read(repositoryProvider).confirmBooking(
            bookingId: booking!.id,
            paymentMethod: method,
            providerRef: payment.providerRef,
          );
      ref.invalidate(myBookingsProvider);
      ref.invalidate(myTicketsProvider);
      ref.invalidate(notificationsProvider);
      if (mounted) context.go('/booking-confirmed/${booking!.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = booking;
    if (value == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final minutes = remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    const methods = {
      'cash': 'Cash / Pay at venue',
      'card': 'Card — Simulated',
      'jazzcash': 'JazzCash — Simulated',
      'easypaisa': 'Easypaisa — Simulated',
      'wallet': 'Wallet — Simulated',
    };

    return AppShell(
      title: 'Checkout',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Reservation hold', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    '$minutes:$seconds',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: remaining.inMinutes < 2 ? Colors.red : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Text('Complete checkout before the hold expires.'),
                ],
              ),
            ),
          ),
          const SectionHeader('Order Summary'),
          Card(
            child: ListTile(
              title: Text(value.bookingCode),
              subtitle: Text(value.customerName),
              trailing: Text(money(value.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SectionHeader('Customer Information'),
          Form(
            key: formKey,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: customerName,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Customer name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) => value == null || value.trim().length < 2
                          ? 'Enter a valid name'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: customerPhone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (value) => value == null || value.trim().length < 7
                          ? 'Enter a valid phone number'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: customerEmail,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) => value == null || !value.contains('@')
                          ? 'Enter a valid email address'
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SectionHeader('Payment Method'),
          RadioGroup<String>(
            groupValue: method,
            onChanged: (value) {
              if (value != null) {
                setState(() => method = value);
              }
            },
            child: Column(
              children: methods.entries
                  .map(
                    (entry) => Card(
                      child: RadioListTile<String>(
                        value: entry.key,
                        title: Text(entry.value),
                        subtitle: entry.key == 'cash'
                            ? null
                            : const Text('Demo provider — no real money is charged'),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 20),
          GradientButton(
            label: remaining == Duration.zero
                ? 'Hold Expired'
                : 'Confirm Booking • ${money(value.totalAmount)}',
            busy: busy,
            onPressed: remaining == Duration.zero ? null : _confirm,
            icon: Icons.lock_outline,
          ),
        ],
      ),
    );
  }
}

class BookingConfirmationScreen extends ConsumerWidget {
  const BookingConfirmationScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: FutureBuilder<Booking>(
            future: ref.read(repositoryProvider).booking(bookingId),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const CircularProgressIndicator();
              }
              if (snapshot.hasError) return ErrorState(message: '${snapshot.error}');
              final value = snapshot.data!;
              return Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(
                      radius: 42,
                      backgroundColor: Colors.green,
                      child: Icon(Icons.check_rounded, color: Colors.white, size: 52),
                    ),
                    const SizedBox(height: 20),
                    Text('Booking Confirmed!', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(value.bookingCode, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(money(value.totalAmount)),
                    const SizedBox(height: 24),
                    GradientButton(
                      label: 'View My Tickets',
                      onPressed: () => context.go('/my-tickets'),
                      icon: Icons.qr_code_2,
                    ),
                    TextButton(onPressed: () => context.go('/home'), child: const Text('Back to Home')),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class BookingDetailsScreen extends ConsumerWidget {
  const BookingDetailsScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      title: 'Booking Details',
      child: FutureBuilder<Booking>(
        future: ref.read(repositoryProvider).booking(bookingId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return ErrorState(message: '${snapshot.error}');
          final booking = snapshot.data!;
          final canCancel = {
            BookingStatus.pending,
            BookingStatus.confirmed,
            BookingStatus.paid,
          }.contains(booking.status);
          final canReview = {
            BookingStatus.completed,
            BookingStatus.used,
          }.contains(booking.status);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(booking.bookingCode, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      StatusChip(booking.status.name),
                      const SizedBox(height: 12),
                      Text('Customer: ${booking.customerName}'),
                      Text('Amount: ${money(booking.totalAmount)}'),
                      Text('Created: ${prettyDate(booking.createdAt)}'),
                    ],
                  ),
                ),
              ),
              if (canReview) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => _leaveReview(context, ref, booking),
                  icon: const Icon(Icons.rate_review_outlined),
                  label: const Text('Leave Review'),
                ),
              ],
              if (canCancel) ...[
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: () => _cancel(context, ref, booking),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel eligible booking'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _leaveReview(BuildContext context, WidgetRef ref, Booking booking) async {
    final rating = ValueNotifier<int>(5);
    final comment = TextEditingController();
    final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Leave a Review'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<int>(
                  valueListenable: rating,
                  builder: (_, value, _) => Wrap(
                    children: List.generate(
                      5,
                      (i) => IconButton(
                        onPressed: () => rating.value = i + 1,
                        icon: Icon(
                          i < value ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  ),
                ),
                TextField(
                  controller: comment,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Comment'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Submit')),
            ],
          ),
        ) ??
        false;
    if (!ok) return;

    try {
      final repo = ref.read(repositoryProvider);
      final schedule = await repo.schedule(booking.scheduleId);
      final listing = await repo.listing(schedule.listingId);
      await repo.createReview(
        bookingId: booking.id,
        businessId: listing.businessId,
        listingId: listing.id,
        rating: rating.value,
        comment: comment.text,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review submitted.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      rating.dispose();
      comment.dispose();
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, Booking booking) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Cancel booking?'),
            content: const Text(
              'Eligible inventory/seats will be released. Paid bookings are recorded as refunded.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Keep booking'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Cancel booking'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;

    try {
      await ref.read(repositoryProvider).cancelBooking(booking.id);
      ref.invalidate(myBookingsProvider);
      ref.invalidate(myTicketsProvider);
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

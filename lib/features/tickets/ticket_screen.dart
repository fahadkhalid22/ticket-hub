import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/widgets/common.dart';
import '../../shared/models/models.dart';
import '../../shared/providers.dart';

class DigitalTicketScreen extends ConsumerWidget {
  const DigitalTicketScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShell(
      title: 'Digital Ticket',
      child: FutureBuilder<DigitalTicket>(
        future: ref.read(repositoryProvider).ticket(ticketId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorState(message: '${snapshot.error}');
          }
          final ticket = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.confirmation_number_rounded),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'TicketHub',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              StatusChip(ticket.status.name),
                            ],
                          ),
                          const Divider(height: 32),
                          Text(
                            ticket.eventTitle ?? 'Ticket',
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          if (ticket.businessName != null)
                            Text(ticket.businessName!),
                          if (ticket.startsAt != null)
                            Text(prettyDate(ticket.startsAt!)),
                          if (ticket.location != null) Text(ticket.location!),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            children: [
                              if (ticket.ticketType != null)
                                Chip(label: Text(ticket.ticketType!)),
                              if (ticket.seatLabel != null)
                                Chip(label: Text('Seat ${ticket.seatLabel}')),
                            ],
                          ),
                          const Divider(height: 34),
                          Container(
                            color: Colors.white,
                            padding: const EdgeInsets.all(14),
                            child: QrImageView(
                              data: ticket.qrToken,
                              size: 210,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            ticket.ticketCode,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const Text(
                            'Present this QR to authorized venue staff. Screenshots remain valid only while ticket status is Valid.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12),
                          ),
                          if (ticket.totalAmount != null) ...[
                            const SizedBox(height: 12),
                            Text('Booking total: ${money(ticket.totalAmount!)}'),
                          ],
                        ],
                      ),
                    ),
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

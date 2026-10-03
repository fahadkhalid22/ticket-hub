import 'package:flutter_test/flutter_test.dart';
import 'package:tickethub/shared/payments/payment_provider.dart';

void main() {
  final provider = SimulatedPaymentProvider();
  test('cash is not marked paid immediately', () async {
    final result = await provider.charge(method: 'cash', amount: 1000, bookingId: 'b1');
    expect(result.paid, isFalse);
  });
  test('simulated card returns provider reference', () async {
    final result = await provider.charge(method: 'card', amount: 1000, bookingId: 'b1');
    expect(result.paid, isTrue);
    expect(result.providerRef, startsWith('SIM-'));
  });
}

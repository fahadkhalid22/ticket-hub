abstract interface class PaymentProvider {
  Future<PaymentResult> charge({required String method, required double amount, required String bookingId});
}

class PaymentResult {
  const PaymentResult({required this.providerRef, required this.paid});
  final String providerRef;
  final bool paid;
}

class SimulatedPaymentProvider implements PaymentProvider {
  @override
  Future<PaymentResult> charge({required String method, required double amount, required String bookingId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final normalized = method.toLowerCase();
    final paid = normalized != 'cash' && normalized != 'pay_at_venue';
    return PaymentResult(
      providerRef: paid ? 'SIM-${DateTime.now().millisecondsSinceEpoch}-$bookingId' : 'PAY-AT-VENUE-$bookingId',
      paid: paid,
    );
  }
}

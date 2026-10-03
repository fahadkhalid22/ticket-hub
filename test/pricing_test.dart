import 'package:flutter_test/flutter_test.dart';
import 'package:tickethub/core/utils/pricing.dart';

void main() {
  test('pricing multiplies each ticket type and applies fee', () {
    final subtotal = Pricing.subtotal([(unitPrice: 800.0, quantity: 2), (unitPrice: 1800.0, quantity: 1)]);
    expect(subtotal, 3400);
    expect(Pricing.serviceFee(subtotal, 2.5), 85);
    expect(Pricing.total(subtotal, 2.5), 3485);
  });
}

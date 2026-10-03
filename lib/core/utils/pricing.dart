class Pricing {
  static double subtotal(Iterable<({double unitPrice, int quantity})> items) => items.fold(0, (sum, item) => sum + item.unitPrice * item.quantity);
  static double serviceFee(double subtotal, double percent) => (subtotal * percent / 100 * 100).roundToDouble() / 100;
  static double total(double subtotal, double percent) => ((subtotal + serviceFee(subtotal, percent)) * 100).roundToDouble() / 100;
}

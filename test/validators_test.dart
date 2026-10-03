import 'package:flutter_test/flutter_test.dart';
import 'package:tickethub/core/utils/validators.dart';

void main() {
  test('email validator rejects malformed addresses', () {
    expect(Validators.email('bad-email'), isNotNull);
    expect(Validators.email('user@example.com'), isNull);
  });
  test('password validator requires eight characters', () {
    expect(Validators.password('1234567'), isNotNull);
    expect(Validators.password('12345678'), isNull);
  });
  test('positive integer validator rejects zero and negatives', () {
    expect(Validators.positiveInt('0'), isNotNull);
    expect(Validators.positiveInt('-2'), isNotNull);
    expect(Validators.positiveInt('6'), isNull);
  });
}

import 'package:cyclone_game/game/number_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatWithCommas inserts thousands separators', () {
    expect(formatWithCommas(0), '0');
    expect(formatWithCommas(999), '999');
    expect(formatWithCommas(1000), '1,000');
    expect(formatWithCommas(12345), '12,345');
    expect(formatWithCommas(123456), '123,456');
    expect(formatWithCommas(1234567), '1,234,567');
    expect(formatWithCommas(-1234567), '-1,234,567');
  });
}

import 'package:cgpa_calculator/core/roles/roles.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a short campus address gets its domain', () {
    expect(
      fullBitsAddress(' F20230800@Goa '),
      'f20230800@goa.bits-pilani.ac.in',
    );
    expect(
      fullBitsAddress('f20230800@hyderabad'),
      'f20230800@hyderabad.bits-pilani.ac.in',
    );
    expect(
      fullBitsAddress('f20230800@goa.bits-pilani.ac.in'),
      'f20230800@goa.bits-pilani.ac.in',
    );
    expect(fullBitsAddress('someone@gmail.com'), 'someone@gmail.com');
    expect(fullBitsAddress('f20230800'), 'f20230800');
    expect(campusOfAddress(fullBitsAddress('f20230800@goa')), 'goa');
  });
}

import 'package:cgpa_calculator/features/resources/link_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('any website is a link; the Reported tab handles bad ones', () {
    expect(isWebLink('https://drive.google.com/x'), isTrue);
    expect(
      isWebLink('https://en.wikipedia.org/wiki/Fourier_transform'),
      isTrue,
    );
    expect(isWebLink('http://example.edu/notes.pdf'), isTrue);
    expect(isWebLink('  https://medium.com/@a/article  '), isTrue);
  });

  test('not a web address', () {
    expect(isWebLink('drive.google.com/x'), isFalse);
    expect(isWebLink('javascript:alert(1)'), isFalse);
    expect(isWebLink('ftp://files.example.com'), isFalse);
    expect(isWebLink('https://localhost'), isFalse);
    expect(isWebLink(''), isFalse);
  });
}

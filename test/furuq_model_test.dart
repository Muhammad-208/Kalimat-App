import 'package:flutter_test/flutter_test.dart';
import 'package:kalimat/data/models/furuq.dart';

/// Guards the safety-critical parsing: a furuq pair is only "verified" when the
/// DB column is exactly 1. Anything else (0, NULL, missing) must read as false,
/// so unverified scholarly comparisons can never be treated as verified.
void main() {
  group('Furuq.fromMap verified flag', () {
    Map<String, Object?> base(Object? verified) => {
          'root_a': 'بحر',
          'root_b': 'يمّ',
          'difference': 'الفرق بين البحر واليمّ',
          'verified': verified,
        };

    test('verified == 1 parses as true', () {
      expect(Furuq.fromMap(base(1)).verified, isTrue);
    });

    test('verified == 0 parses as false', () {
      expect(Furuq.fromMap(base(0)).verified, isFalse);
    });

    test('verified == null parses as false', () {
      expect(Furuq.fromMap(base(null)).verified, isFalse);
    });

    test('core fields round-trip from the map', () {
      final f = Furuq.fromMap(base(1));
      expect(f.rootA, 'بحر');
      expect(f.rootB, 'يمّ');
      expect(f.difference, 'الفرق بين البحر واليمّ');
    });
  });
}

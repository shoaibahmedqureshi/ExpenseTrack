import 'package:flutter_test/flutter_test.dart';
import 'package:outlay/features/family_accounts/domain/family_access.dart';

void main() {
  group('canManageFamilyMembers', () {
    test('only an admin with MAX can invite', () {
      expect(canManageFamilyMembers(isMax: true, isAdmin: true), isTrue);
      expect(canManageFamilyMembers(isMax: false, isAdmin: true), isFalse);
      expect(canManageFamilyMembers(isMax: true, isAdmin: false), isFalse);
      expect(canManageFamilyMembers(isMax: false, isAdmin: false), isFalse);
    });
  });
}

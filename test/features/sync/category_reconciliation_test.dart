import 'package:flutter_test/flutter_test.dart';
import 'package:outlay/features/sync/category_reconciliation.dart';

void main() {
  group('planCategoryPush', () {
    test('creates new when no remote category matches the name', () {
      final result = planCategoryPush(
        localName: 'Food',
        remoteCategories: [
          {'id': 1, 'name': 'Transport'},
        ],
      );
      expect(result.shouldCreateNew, isTrue);
      expect(result.existingRemoteId, isNull);
    });

    test('links to existing remote category with matching name', () {
      final result = planCategoryPush(
        localName: 'Food',
        remoteCategories: [
          {'id': 1, 'name': 'Transport'},
          {'id': 42, 'name': 'Food'},
        ],
      );
      expect(result.shouldCreateNew, isFalse);
      expect(result.existingRemoteId, '42');
    });

    test('name match is case-insensitive and trims whitespace', () {
      final result = planCategoryPush(
        localName: '  food  ',
        remoteCategories: [
          {'id': 42, 'name': 'FOOD'},
        ],
      );
      expect(result.existingRemoteId, '42');
    });

    test('empty remote list always creates new', () {
      final result =
          planCategoryPush(localName: 'Food', remoteCategories: []);
      expect(result.shouldCreateNew, isTrue);
    });
  });

  group('planPullCategory', () {
    test('already linked when a local row has this exact remote_id', () {
      final action = planPullCategory(
        remoteRow: {'id': 10, 'name': 'Food'},
        localCategories: [
          {'id': 1, 'name': 'Food', 'remote_id': '10'},
        ],
      );
      expect(action.type, PullCategoryActionType.alreadyLinked);
    });

    test('links an unlinked local row with the same name', () {
      final action = planPullCategory(
        remoteRow: {'id': 10, 'name': 'Food'},
        localCategories: [
          {'id': 5, 'name': 'Food', 'remote_id': null},
        ],
      );
      expect(action.type, PullCategoryActionType.linkExistingLocal);
      expect(action.localIdToLink, 5);
    });

    test('name match for linking is case-insensitive / trimmed', () {
      final action = planPullCategory(
        remoteRow: {'id': 10, 'name': '  Food  '},
        localCategories: [
          {'id': 5, 'name': 'FOOD', 'remote_id': null},
        ],
      );
      expect(action.type, PullCategoryActionType.linkExistingLocal);
    });

    test('inserts new when nothing local matches at all', () {
      final action = planPullCategory(
        remoteRow: {'id': 10, 'name': 'Groceries'},
        localCategories: [
          {'id': 5, 'name': 'Food', 'remote_id': '99'},
        ],
      );
      expect(action.type, PullCategoryActionType.insertNew);
    });

    test(
        'CRITICAL: inserts new (never skips) when the name is already '
        'linked to a *different* remote id — this is the exact bug that '
        'caused expenses to silently disappear. A pre-existing remote '
        'duplicate ("Food" #10 and "Food" #11, both real rows in Supabase '
        'from before push-side reconciliation existed) must still get a '
        'local row for #11, or _pullRemoteExpenses can never resolve any '
        'expense that references category_id 11 and will skip it forever.',
        () {
      final action = planPullCategory(
        remoteRow: {'id': 11, 'name': 'Food'}, // the duplicate remote row
        localCategories: [
          // Already linked to the *other* Food (id 10), not 11.
          {'id': 5, 'name': 'Food', 'remote_id': '10'},
        ],
      );
      expect(action.type, PullCategoryActionType.insertNew,
          reason: 'must never be "skip" — see test description');
    });

    test('does not confuse an already-linked-to-this-id row with a '
        'same-name different-id row when both exist locally', () {
      final action = planPullCategory(
        remoteRow: {'id': 10, 'name': 'Food'},
        localCategories: [
          {'id': 5, 'name': 'Food', 'remote_id': '10'}, // this one matches
          {'id': 6, 'name': 'Food', 'remote_id': '11'}, // unrelated
        ],
      );
      expect(action.type, PullCategoryActionType.alreadyLinked);
    });
  });

  group('planCategoryDedupe', () {
    test('no groups when every category name is unique', () {
      final groups = planCategoryDedupe([
        {'id': 1, 'name': 'Food', 'remote_id': null},
        {'id': 2, 'name': 'Transport', 'remote_id': null},
      ]);
      expect(groups, isEmpty);
    });

    test('groups two same-named categories and picks the linked one as '
        'keeper regardless of id order', () {
      final groups = planCategoryDedupe([
        {'id': 5, 'name': 'Food', 'remote_id': null}, // seeded, unlinked
        {'id': 2, 'name': 'Food', 'remote_id': '10'}, // linked, lower id
      ]);
      expect(groups, hasLength(1));
      expect(groups.first.keeperId, 2);
      expect(groups.first.duplicateIds, [5]);
    });

    test('ties between two unlinked rows break by lowest id', () {
      final groups = planCategoryDedupe([
        {'id': 7, 'name': 'Food', 'remote_id': null},
        {'id': 3, 'name': 'Food', 'remote_id': null},
      ]);
      expect(groups.first.keeperId, 3);
      expect(groups.first.duplicateIds, [7]);
    });

    test('ties between two linked rows break by lowest id', () {
      final groups = planCategoryDedupe([
        {'id': 7, 'name': 'Food', 'remote_id': '99'},
        {'id': 3, 'name': 'Food', 'remote_id': '10'},
      ]);
      expect(groups.first.keeperId, 3);
      expect(groups.first.duplicateIds, [7]);
    });

    test('handles three-way duplicates, keeping exactly one keeper', () {
      final groups = planCategoryDedupe([
        {'id': 1, 'name': 'Food', 'remote_id': null},
        {'id': 2, 'name': 'Food', 'remote_id': '10'},
        {'id': 3, 'name': 'Food', 'remote_id': null},
      ]);
      expect(groups, hasLength(1));
      expect(groups.first.keeperId, 2);
      expect(groups.first.duplicateIds, unorderedEquals([1, 3]));
    });

    test('multiple distinct duplicate groups are each resolved '
        'independently', () {
      final groups = planCategoryDedupe([
        {'id': 1, 'name': 'Food', 'remote_id': null},
        {'id': 2, 'name': 'Food', 'remote_id': '10'},
        {'id': 3, 'name': 'Transport', 'remote_id': null},
        {'id': 4, 'name': 'Transport', 'remote_id': '20'},
        {'id': 5, 'name': 'Health', 'remote_id': '30'}, // no duplicate
      ]);
      expect(groups, hasLength(2));
      final byKeeper = {for (final g in groups) g.keeperId: g.duplicateIds};
      expect(byKeeper[2], [1]);
      expect(byKeeper[4], [3]);
    });

    test('name grouping is case-insensitive and trims whitespace', () {
      final groups = planCategoryDedupe([
        {'id': 1, 'name': 'Food', 'remote_id': null},
        {'id': 2, 'name': '  FOOD  ', 'remote_id': '10'},
      ]);
      expect(groups, hasLength(1));
      expect(groups.first.keeperId, 2);
    });
  });
}

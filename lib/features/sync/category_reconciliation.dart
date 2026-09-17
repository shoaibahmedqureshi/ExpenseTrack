/// Pure decision logic for reconciling categories between the local SQLite
/// DB and the remote Supabase table — no Database or SupabaseClient
/// dependency, so every rule here is unit-testable with plain data and no
/// mocking.
///
/// Categories have no identifier shared between devices until they're
/// first linked, and each device seeds its own copy of the same default
/// set independently — so matching has to fall back to name when there's
/// no remote_id yet.
///
/// The one invariant every rule here preserves: once a remote category id
/// has been seen during a pull, a local row with that exact remote_id must
/// exist afterwards. Expense/budget pulling resolves categories by
/// remote_id alone (see SyncService._pullRemoteExpenses) — any remote
/// category id with no corresponding local row silently orphans every
/// expense/budget that references it: they're skipped, forever, every
/// sync, with no error. An earlier version of this file's logic violated
/// that invariant by skipping local-row creation for a remote category
/// that was a same-name duplicate of something already linked — which
/// looked like "previous data disappeared" for anyone whose expenses
/// happened to be tied to the duplicate id.
library;

class RemoteCategoryLinkResult {
  /// Set when an existing remote category with the same name was found —
  /// the local row should link to it rather than push a new remote row.
  final String? existingRemoteId;

  const RemoteCategoryLinkResult({this.existingRemoteId});

  bool get shouldCreateNew => existingRemoteId == null;
}

/// Decides, for one pending local category push, whether to link to an
/// existing remote category with the same name (case-insensitive, trimmed)
/// or create a new one. This is what stops every device's independently
/// seeded "Food" from becoming a second remote row.
RemoteCategoryLinkResult planCategoryPush({
  required String localName,
  required List<Map<String, dynamic>> remoteCategories,
}) {
  final normalized = localName.trim().toLowerCase();
  for (final remote in remoteCategories) {
    if ((remote['name'] as String).trim().toLowerCase() == normalized) {
      return RemoteCategoryLinkResult(
          existingRemoteId: remote['id'].toString());
    }
  }
  return const RemoteCategoryLinkResult();
}

enum PullCategoryActionType { alreadyLinked, linkExistingLocal, insertNew }

class PullCategoryAction {
  final PullCategoryActionType type;

  /// Local row id to attach the remote_id to — only set when
  /// type == linkExistingLocal.
  final int? localIdToLink;

  const PullCategoryAction._(this.type, this.localIdToLink);

  static const alreadyLinked =
      PullCategoryAction._(PullCategoryActionType.alreadyLinked, null);
  static const insertNew =
      PullCategoryAction._(PullCategoryActionType.insertNew, null);

  factory PullCategoryAction.link(int localId) =>
      PullCategoryAction._(PullCategoryActionType.linkExistingLocal, localId);
}

/// Decides what to do with one remote category row during a pull.
///
/// Deliberately never "skip" as an outcome — see the invariant in the
/// library doc comment above. When there's no unlinked local row to attach
/// to (a local category with this name already links to a *different*
/// remote id — a pre-existing duplicate from before push-side
/// reconciliation existed), the answer is [insertNew], which creates a
/// second local row for now. [planCategoryDedupe] cleans that up
/// afterwards, once every expense/budget for this sync pass has already
/// been pulled and correctly points at it.
PullCategoryAction planPullCategory({
  required Map<String, dynamic> remoteRow,
  required List<Map<String, Object?>> localCategories,
}) {
  final remoteId = remoteRow['id'].toString();
  final name = (remoteRow['name'] as String).trim().toLowerCase();

  for (final local in localCategories) {
    if (local['remote_id']?.toString() == remoteId) {
      return PullCategoryAction.alreadyLinked;
    }
  }

  for (final local in localCategories) {
    final localName = (local['name'] as String).trim().toLowerCase();
    if (localName == name && local['remote_id'] == null) {
      return PullCategoryAction.link(local['id'] as int);
    }
  }

  return PullCategoryAction.insertNew;
}

class CategoryMergeGroup {
  final Object keeperId;
  final List<Object> duplicateIds;
  const CategoryMergeGroup(
      {required this.keeperId, required this.duplicateIds});
}

/// Groups local categories by normalized name and, for every group with
/// more than one row, picks a keeper (prefer one already linked to a
/// remote id — that id is what other devices recognize — then lowest
/// local id) and lists the rest as duplicates to merge into it.
///
/// This only decides *which* rows; the caller is responsible for
/// reassigning every expense/budget referencing a duplicate id onto
/// keeperId *before* deleting the duplicate row, so nothing is orphaned.
List<CategoryMergeGroup> planCategoryDedupe(
  List<Map<String, Object?>> localCategories,
) {
  final byName = <String, List<Map<String, Object?>>>{};
  for (final row in localCategories) {
    final key = (row['name'] as String).trim().toLowerCase();
    byName.putIfAbsent(key, () => []).add(row);
  }

  final groups = <CategoryMergeGroup>[];
  for (final rows in byName.values) {
    if (rows.length < 2) continue;

    final sorted = [...rows]
      ..sort((a, b) {
        final aLinked = a['remote_id'] != null;
        final bLinked = b['remote_id'] != null;
        if (aLinked != bLinked) return aLinked ? -1 : 1;
        return (a['id'] as int).compareTo(b['id'] as int);
      });

    groups.add(CategoryMergeGroup(
      keeperId: sorted.first['id'] as Object,
      duplicateIds: sorted.skip(1).map((r) => r['id'] as Object).toList(),
    ));
  }
  return groups;
}

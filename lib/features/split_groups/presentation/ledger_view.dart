import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../expense_split/domain/split_models.dart';
import '../../expense_split/presentation/providers/expense_split_provider.dart';
import '../../family_accounts/domain/entities/family_member.dart';
import '../../family_accounts/presentation/providers/family_provider.dart';
import '../domain/group_models.dart';
import 'providers/split_group_provider.dart';

/// What the Splits tab, the new-split form and the dashboard card need to know about the ledger
/// (the family or a group) the person is currently looking at.
class LedgerView {
  const LedgerView({required this.available, required this.ledger, required this.members, required this.isOwner});
  final List<Ledger> available;
  final Ledger? ledger;
  final List<LedgerMember> members;
  final bool isOwner;

  bool get isGroup => ledger?.kind == LedgerKind.group;
}

/// Reads (and listens to) the providers and works out the current ledger. Call from `build`.
LedgerView watchLedgerView(BuildContext context) => _resolve(
      context.watch<FamilyProvider>(),
      context.watch<SplitGroupProvider>(),
      context.watch<ExpenseSplitProvider>(),
    );

/// The same, without listening: for use in button callbacks.
LedgerView watchLedgerViewOnce(BuildContext context) => _resolve(
      context.read<FamilyProvider>(),
      context.read<SplitGroupProvider>(),
      context.read<ExpenseSplitProvider>(),
    );

LedgerView _resolve(FamilyProvider family, SplitGroupProvider groups, ExpenseSplitProvider sp) {

  final familyLedger = family.hasFamily
      ? Ledger(LedgerKind.family, int.tryParse(family.currentFamily!.id) ?? 0, family.currentFamily!.name)
      : null;
  final available = availableLedgers(family: familyLedger, groups: groups.groups);
  final ledger = chooseLedger(available, sp.ledger);

  List<LedgerMember> members = const [];
  var isOwner = false;
  if (ledger?.kind == LedgerKind.family) {
    members = [
      for (final m in family.familyMembers)
        LedgerMember(userId: m.userId, email: m.email, name: m.name, isOwner: m.role == FamilyMemberRole.admin)
    ];
    isOwner = family.isFamilyAdmin;
  } else if (ledger != null) {
    members = groups.membersOf(ledger.id);
    isOwner = groups.byId(ledger.id)?.isOwner ?? false;
  }
  return LedgerView(available: available, ledger: ledger, members: members, isOwner: isOwner);
}

/// Loads the ledger's splits (and a group's members) once after the view settles on it.
void ensureLedgerLoaded(BuildContext context, LedgerView view) {
  final sp = context.read<ExpenseSplitProvider>();
  final l = view.ledger;
  if (l == null) {
    if (sp.ledger != null) WidgetsBinding.instance.addPostFrameCallback((_) => sp.clear());
    return;
  }
  if (sp.ledger != l) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      sp.ensureLoaded(l);
      if (l.kind == LedgerKind.group) context.read<SplitGroupProvider>().loadGroup(l.id);
    });
  } else if (l.kind == LedgerKind.group && view.members.isEmpty) {
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<SplitGroupProvider>().loadGroup(l.id));
  }
}

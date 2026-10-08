/// Creating a family, and inviting people into it, needs an active MAX plan. If an admin's plan lapses
/// the family and its existing members stay, but no new members can be invited.
bool canManageFamilyMembers({required bool isMax, required bool isAdmin}) => isMax && isAdmin;

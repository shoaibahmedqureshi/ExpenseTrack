// Reads and writes public.user_entitlements with the service role. The row is only ever written from something a
// store has vouched for (a verified Apple JWS, or a Play API response), never from client-supplied plan data.
import type { Entitlement } from './entitlement.ts';

// deno-lint-ignore no-explicit-any
type Admin = any;
export type Store = 'apple' | 'google';

/** Webhook path: bring an existing row up to date. No row (the user never synced) means nothing to do. */
export async function refreshEntitlement(admin: Admin, store: Store, ent: Entitlement): Promise<void> {
  const { error } = await admin
    .from('user_entitlements')
    .update({
      plan: ent.plan,
      product_id: ent.productId,
      expires_at: ent.expiresAt.toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq('store', store)
    .eq('original_transaction_id', ent.originalTransactionId);
  if (error) throw error;
}

/** Refund / chargeback: access ends now. */
export async function endEntitlement(admin: Admin, store: Store, originalTransactionId: string): Promise<void> {
  const { error } = await admin
    .from('user_entitlements')
    .update({ expires_at: new Date().toISOString(), updated_at: new Date().toISOString() })
    .eq('store', store)
    .eq('original_transaction_id', originalTransactionId);
  if (error) throw error;
}

/**
 * Client sync path: attach a verified entitlement to a user. One store subscription belongs to one account: if
 * another account already holds it and it is still current, refuse rather than let it be claimed twice.
 */
export async function linkEntitlement(
  admin: Admin,
  userId: string,
  store: Store,
  ent: Entitlement,
): Promise<'ok' | 'claimed'> {
  const { data: existing, error: readError } = await admin
    .from('user_entitlements')
    .select('user_id, expires_at')
    .eq('store', store)
    .eq('original_transaction_id', ent.originalTransactionId)
    .maybeSingle();
  if (readError) throw readError;

  if (existing && existing.user_id !== userId && new Date(existing.expires_at) > new Date()) {
    return 'claimed';
  }
  if (existing && existing.user_id !== userId) {
    // The earlier holder's entitlement has already ended; free the (store, transaction) pair for the new owner.
    const { error: delError } = await admin.from('user_entitlements').delete().eq('user_id', existing.user_id);
    if (delError) throw delError;
  }

  const { error } = await admin.from('user_entitlements').upsert(
    {
      user_id: userId,
      plan: ent.plan,
      store,
      original_transaction_id: ent.originalTransactionId,
      product_id: ent.productId,
      expires_at: ent.expiresAt.toISOString(),
      updated_at: new Date().toISOString(),
    },
    { onConflict: 'user_id' },
  );
  if (error) throw error;
  return 'ok';
}

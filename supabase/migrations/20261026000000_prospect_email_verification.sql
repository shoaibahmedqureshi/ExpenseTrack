-- Outreach addresses must come from a page the creator published, never from a model's guess.
alter table public.influencer_prospects
  add column if not exists email_status text not null default 'unverified',
  add column if not exists email_source text,
  add column if not exists email_verified_at timestamptz,
  add column if not exists verify_attempted_at timestamptz,
  add column if not exists verify_note text,
  add column if not exists email_guess text;

alter table public.influencer_prospects
  drop constraint if exists influencer_prospects_email_status_check,
  add constraint influencer_prospects_email_status_check
    check (email_status in ('unverified', 'verified', 'not_found'));

alter table public.influencer_prospects alter column email drop not null;

-- Everything stored so far was guessed: keep it for reference, but it is no longer a contact.
update public.influencer_prospects
   set email_guess = email, email = null
 where email is not null and email_status = 'unverified' and email_guess is null;

create index if not exists influencer_prospects_verify_queue
  on public.influencer_prospects (email_status, verify_attempted_at nulls first);

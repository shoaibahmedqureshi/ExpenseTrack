-- Approving an application and queueing its follow-up task now happen in one transaction.
-- Before, the app saved the decision and then inserted the task; if the second step failed,
-- the application stayed approved with nothing in the queue.

CREATE OR REPLACE FUNCTION public.admin_approve_application(
  p_id BIGINT,
  p_notes TEXT,
  p_draft TEXT,
  p_task_notes TEXT
) RETURNS BIGINT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  a public.creator_applications%ROWTYPE;
  task_id BIGINT;
BEGIN
  IF NOT public.is_app_admin() THEN
    RAISE EXCEPTION 'not allowed' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO a FROM public.creator_applications WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'application not found';
  END IF;
  IF a.status <> 'confirmed' THEN
    RAISE EXCEPTION 'only a confirmed application can be approved (this one is %)', a.status;
  END IF;

  UPDATE public.creator_applications
     SET status = 'approved',
         admin_notes = NULLIF(btrim(p_notes), ''),
         decided_by = auth.uid(),
         decided_at = now()
   WHERE id = p_id;

  INSERT INTO public.outreach_tasks
    (creator_name, platform, channel, handle, profile_url, niche, draft_message, notes, source, application_id, created_by)
  VALUES
    (a.name, 'email', 'email', NULLIF(btrim(a.handle), ''),
     CASE WHEN a.profile_url ~* '^https?://' THEN a.profile_url END,
     a.niche, NULLIF(btrim(p_draft), ''), NULLIF(btrim(p_task_notes), ''), 'application', a.id, auth.uid())
  RETURNING id INTO task_id;

  RETURN task_id;
END $$;

REVOKE ALL ON FUNCTION public.admin_approve_application(BIGINT, TEXT, TEXT, TEXT) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.admin_approve_application(BIGINT, TEXT, TEXT, TEXT) TO authenticated;

-- Slash Jobs BD: automatic permanent deletion of expired Trash jobs
-- Run this script ONCE in Supabase Dashboard -> SQL Editor.
-- Jobs are permanently deleted only after their recorded trashedAt is at least 7 days old.
-- Only rows still in rejected status with the private Trash marker are eligible.
-- Restored jobs no longer have the marker and are never selected.

create extension if not exists pg_cron;

create or replace function public.purge_expired_slash_jobs_trash()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  job_record record;
  trash_meta jsonb;
  trashed_at timestamptz;
  deleted_count integer := 0;
  trash_prefix constant text := '__SJBD_TRASH_V1__';
begin
  for job_record in
    select id, reject_reason
    from public.jobs
    where status = 'rejected'
      and left(coalesce(reject_reason, ''), length(trash_prefix)) = trash_prefix
  loop
    begin
      trash_meta := substring(job_record.reject_reason from length(trash_prefix) + 1)::jsonb;
      trashed_at := nullif(trash_meta ->> 'trashedAt', '')::timestamptz;

      if trashed_at is not null and trashed_at <= now() - interval '7 days' then
        delete from public.jobs
        where id = job_record.id
          and status = 'rejected'
          and reject_reason = job_record.reject_reason;

        if found then
          deleted_count := deleted_count + 1;
        end if;
      end if;
    exception when others then
      -- Skip malformed legacy metadata instead of stopping the whole cleanup run.
      raise warning 'Skipped Trash row % because its metadata could not be parsed.', job_record.id;
    end;
  end loop;

  return deleted_count;
end;
$function$;

-- The function is intended to be called only by the scheduled database job.
revoke all on function public.purge_expired_slash_jobs_trash() from public;
revoke all on function public.purge_expired_slash_jobs_trash() from anon;
revoke all on function public.purge_expired_slash_jobs_trash() from authenticated;

-- Re-running this setup replaces the existing schedule instead of duplicating it.
select cron.unschedule(jobid)
from cron.job
where jobname = 'slash-jobs-bd-trash-purge';

-- Runs daily at 00:15 UTC (06:15 Bangladesh time).
select cron.schedule(
  'slash-jobs-bd-trash-purge',
  '15 0 * * *',
  $command$select public.purge_expired_slash_jobs_trash();$command$
);

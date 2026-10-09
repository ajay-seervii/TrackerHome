-- =====================================================================
-- Pivot Tracker database setup
-- Safe to re-run: creates missing objects, adds missing columns, and
-- replaces functions/policies. It never drops tables, columns, or rows.
-- Run the whole file in Supabase Dashboard -> SQL Editor.
-- One-time bootstrap commands are at the bottom (STEP 2).
-- =====================================================================

begin;

create extension if not exists pgcrypto;

create or replace function pg_temp.ensure_constraint(p_table regclass, p_name text, p_def text)
returns void language plpgsql as $$
begin
  if not exists (select 1 from pg_constraint where conrelid = p_table and conname = p_name) then
    execute format('alter table %s add constraint %I %s', p_table, p_name, p_def);
  end if;
end $$;

-- ---------------------------------------------------------------------
-- users: a row here means the account is approved
-- ---------------------------------------------------------------------
create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique,
  created_at timestamptz not null default now()
);
alter table public.users add column if not exists display_name text;
alter table public.users add column if not exists timezone text not null default 'UTC';

create or replace function public.pt__users_guard() returns trigger
language plpgsql set search_path = public as $$
begin
  -- Raises for unknown zone names so streak maths never fails later.
  perform now() at time zone new.timezone;
  if new.display_name is not null then
    new.display_name := left(btrim(new.display_name), 60);
  end if;
  return new;
end $$;
drop trigger if exists pt_users_guard on public.users;
create trigger pt_users_guard before insert or update on public.users
  for each row execute function public.pt__users_guard();

-- ---------------------------------------------------------------------
-- trackers
-- ---------------------------------------------------------------------
create table if not exists public.trackers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);
alter table public.trackers add column if not exists slug text;
alter table public.trackers add column if not exists page text;
alter table public.trackers add column if not exists icon text not null default 'target';
alter table public.trackers add column if not exists ruleset text not null default 'standard';
alter table public.trackers add column if not exists allow_uncheck boolean not null default true;
alter table public.trackers add column if not exists requires_approval boolean not null default false;
alter table public.trackers add column if not exists sort_order int not null default 0;

select pg_temp.ensure_constraint('public.trackers', 'trackers_slug_format', $c$check (slug is null or slug ~ '^[a-z0-9-]{1,40}$')$c$);
select pg_temp.ensure_constraint('public.trackers', 'trackers_page_format', $c$check (page is null or page ~ '^[a-z0-9_]+\.html$')$c$);
select pg_temp.ensure_constraint('public.trackers', 'trackers_icon_format', $c$check (icon ~ '^[a-z-]{1,30}$')$c$);
select pg_temp.ensure_constraint('public.trackers', 'trackers_ruleset_valid', $c$check (ruleset in ('standard', 'godot'))$c$);
-- Godot keeps level/achievement aggregates that cannot be rolled back safely.
select pg_temp.ensure_constraint('public.trackers', 'trackers_godot_no_uncheck', $c$check (ruleset <> 'godot' or not allow_uncheck)$c$);
create unique index if not exists trackers_slug_uidx on public.trackers(slug) where slug is not null;

-- ---------------------------------------------------------------------
-- tracker_access: owner = own progress, member = own progress (approval
-- may apply), guardian = reviews members' completions, no own progress
-- ---------------------------------------------------------------------
create table if not exists public.tracker_access (
  id uuid primary key default gen_random_uuid(),
  tracker_id uuid not null references public.trackers(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  can_edit boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.tracker_access add column if not exists role text not null default 'member';
select pg_temp.ensure_constraint('public.tracker_access', 'tracker_access_role_valid', $c$check (role in ('owner', 'member', 'guardian'))$c$);
create unique index if not exists tracker_access_tracker_user_uidx on public.tracker_access(tracker_id, user_id);
create index if not exists tracker_access_user_idx on public.tracker_access(user_id);

update public.tracker_access a set role = 'owner'
from public.trackers t
where t.id = a.tracker_id and t.created_by = a.user_id and a.role = 'member';

-- ---------------------------------------------------------------------
-- progress: legacy aggregate row per user x tracker. Still the source of
-- Godot level/current XP/achievements/skills; legacy arrays kept as backup.
-- ---------------------------------------------------------------------
create table if not exists public.progress (
  id uuid primary key default gen_random_uuid(),
  tracker_id uuid not null references public.trackers(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  level int not null default 1,
  current_xp int not null default 0,
  total_xp int not null default 0,
  completed_tasks text[] not null default '{}',
  unlocked_achievements text[] not null default '{}',
  unlocked_skills text[] not null default '{}',
  updated_at timestamptz not null default now()
);
alter table public.progress add column if not exists migrated_at timestamptz;
create unique index if not exists progress_tracker_user_uidx on public.progress(tracker_id, user_id);

-- ---------------------------------------------------------------------
-- tasks: definitions and their grouping (phase/week/section/divider)
-- ---------------------------------------------------------------------
create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  tracker_id uuid not null references public.trackers(id) on delete cascade,
  parent_id uuid references public.tasks(id),
  kind text not null default 'task',
  title text not null,
  created_at timestamptz not null default now()
);
alter table public.tasks add column if not exists description text;
alter table public.tasks add column if not exists xp int not null default 0;
alter table public.tasks add column if not exists difficulty text;
alter table public.tasks add column if not exists week_number int;
alter table public.tasks add column if not exists time_estimate text;
alter table public.tasks add column if not exists sort_order int not null default 0;
alter table public.tasks add column if not exists seed_key text;
alter table public.tasks add column if not exists legacy_key text;
alter table public.tasks add column if not exists archived_at timestamptz;
alter table public.tasks add column if not exists updated_at timestamptz not null default now();
alter table public.tasks add column if not exists month_number int generated always as ((week_number + 3) / 4) stored;

select pg_temp.ensure_constraint('public.tasks', 'tasks_kind_valid', $c$check (kind in ('phase', 'week', 'section', 'task', 'divider'))$c$);
select pg_temp.ensure_constraint('public.tasks', 'tasks_title_length', $c$check (char_length(btrim(title)) between 1 and 300)$c$);
select pg_temp.ensure_constraint('public.tasks', 'tasks_xp_range', $c$check (xp between 0 and 10000)$c$);
select pg_temp.ensure_constraint('public.tasks', 'tasks_group_no_xp', $c$check (kind = 'task' or xp = 0)$c$);
select pg_temp.ensure_constraint('public.tasks', 'tasks_difficulty_valid', $c$check (difficulty is null or difficulty in ('easy', 'medium', 'hard'))$c$);
select pg_temp.ensure_constraint('public.tasks', 'tasks_week_range', $c$check (week_number is null or week_number between 1 and 520)$c$);
select pg_temp.ensure_constraint('public.tasks', 'tasks_time_estimate_length', $c$check (time_estimate is null or char_length(time_estimate) <= 40)$c$);
select pg_temp.ensure_constraint('public.tasks', 'tasks_description_length', $c$check (description is null or char_length(description) <= 2000)$c$);
create unique index if not exists tasks_tracker_seed_uidx on public.tasks(tracker_id, seed_key);
create unique index if not exists tasks_tracker_legacy_uidx on public.tasks(tracker_id, legacy_key);
create index if not exists tasks_tracker_parent_idx on public.tasks(tracker_id, parent_id, sort_order);

create or replace function public.pt__tasks_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  par public.tasks;
  cur uuid;
  depth int := 0;
begin
  if tg_op = 'UPDATE' then
    if new.tracker_id <> old.tracker_id then
      raise exception 'A task cannot move to another tracker';
    end if;
    if new.kind <> old.kind and old.kind <> 'task' and new.kind in ('task', 'divider')
       and exists (select 1 from public.tasks where parent_id = new.id) then
      raise exception 'Items that contain other items must stay groups';
    end if;
    if old.kind = 'task' and new.kind <> 'task'
       and exists (select 1 from public.task_progress where task_id = new.id) then
      raise exception 'This task has progress recorded; archive it instead of changing its kind';
    end if;
  end if;

  if new.parent_id is not null then
    select * into par from public.tasks where id = new.parent_id;
    if not found then
      raise exception 'Parent item not found';
    end if;
    if par.tracker_id <> new.tracker_id then
      raise exception 'Parent must belong to the same tracker';
    end if;
    if par.kind in ('task', 'divider') then
      raise exception 'A % cannot contain other items', par.kind;
    end if;
    cur := par.id;
    while cur is not null loop
      if cur = new.id then
        raise exception 'That parent would create a loop';
      end if;
      depth := depth + 1;
      if depth > 20 then
        raise exception 'Hierarchy is too deep';
      end if;
      select parent_id into cur from public.tasks where id = cur;
    end loop;
    if par.week_number is not null then
      new.week_number := par.week_number;
    end if;
  end if;

  new.title := btrim(new.title);
  new.updated_at := now();
  return new;
end $$;

create or replace function public.pt__tasks_cascade_week() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.week_number is distinct from old.week_number then
    update public.tasks set week_number = new.week_number
    where parent_id = new.id and week_number is distinct from new.week_number;
  end if;
  return null;
end $$;

-- ---------------------------------------------------------------------
-- task_resources: links attached to a group or task
-- ---------------------------------------------------------------------
create table if not exists public.task_resources (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks(id) on delete cascade,
  title text not null,
  url text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);
select pg_temp.ensure_constraint('public.task_resources', 'task_resources_url_http', $c$check (url ~* '^https?://[^\s]+$' and char_length(url) <= 500)$c$);
select pg_temp.ensure_constraint('public.task_resources', 'task_resources_title_length', $c$check (char_length(btrim(title)) between 1 and 120)$c$);
create unique index if not exists task_resources_task_url_uidx on public.task_resources(task_id, url);

-- ---------------------------------------------------------------------
-- task_progress: one row per user x task while it is done or awaiting review.
-- Unchecking deletes the row; the XP ledger keeps the history.
-- ---------------------------------------------------------------------
create table if not exists public.task_progress (
  id uuid primary key default gen_random_uuid(),
  tracker_id uuid not null references public.trackers(id) on delete cascade,
  task_id uuid not null references public.tasks(id),
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending',
  completed_at timestamptz not null default now(),
  awarded_xp int,
  approved_by uuid references auth.users(id),
  approved_at timestamptz,
  updated_at timestamptz not null default now()
);
select pg_temp.ensure_constraint('public.task_progress', 'task_progress_status_valid', $c$check (status in ('pending', 'approved', 'rejected'))$c$);
create unique index if not exists task_progress_user_task_uidx on public.task_progress(user_id, task_id);
create index if not exists task_progress_tracker_status_idx on public.task_progress(tracker_id, status);

-- Created after task_progress exists because the guard references it.
drop trigger if exists pt_tasks_guard on public.tasks;
create trigger pt_tasks_guard before insert or update on public.tasks
  for each row execute function public.pt__tasks_guard();
drop trigger if exists pt_tasks_cascade_week on public.tasks;
create trigger pt_tasks_cascade_week after update of week_number on public.tasks
  for each row execute function public.pt__tasks_cascade_week();

-- ---------------------------------------------------------------------
-- xp_events: append-only XP ledger. Life XP, activity feed and per-tracker
-- XP are all sums over this table.
-- ---------------------------------------------------------------------
create table if not exists public.xp_events (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  tracker_id uuid not null references public.trackers(id) on delete cascade,
  task_id uuid references public.tasks(id) on delete set null,
  amount int not null,
  reason text not null,
  note text,
  occurred_on date not null default current_date,
  created_at timestamptz not null default now()
);
select pg_temp.ensure_constraint('public.xp_events', 'xp_events_reason_valid', $c$check (reason in ('task', 'achievement', 'legacy_balance', 'refund', 'reset', 'adjustment'))$c$);
create index if not exists xp_events_user_created_idx on public.xp_events(user_id, created_at desc);
create index if not exists xp_events_tracker_user_idx on public.xp_events(tracker_id, user_id);
create unique index if not exists xp_events_legacy_once_uidx on public.xp_events(user_id, tracker_id) where reason = 'legacy_balance';

-- =====================================================================
-- Access helpers (used by RLS policies)
-- =====================================================================
create or replace function public.pt_is_approved() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.users where id = auth.uid());
$$;

create or replace function public.pt_tracker_role(p_tracker uuid) returns text
language sql stable security definer set search_path = public as $$
  select a.role from public.tracker_access a
  where a.tracker_id = p_tracker and a.user_id = auth.uid() and public.pt_is_approved();
$$;

create or replace function public.pt_is_creator(p_tracker uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select public.pt_is_approved() and exists (
    select 1 from public.trackers where id = p_tracker and created_by = auth.uid()
  );
$$;

-- =====================================================================
-- Row level security. Existing policies on these tables are replaced so
-- older permissive rules (such as self-approval) cannot linger.
-- =====================================================================
do $$
declare r record;
begin
  for r in
    select policyname, tablename from pg_policies
    where schemaname = 'public'
      and tablename in ('users', 'trackers', 'tracker_access', 'progress', 'tasks', 'task_resources', 'task_progress', 'xp_events')
  loop
    execute format('drop policy %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

alter table public.users enable row level security;
alter table public.trackers enable row level security;
alter table public.tracker_access enable row level security;
alter table public.progress enable row level security;
alter table public.tasks enable row level security;
alter table public.task_resources enable row level security;
alter table public.task_progress enable row level security;
alter table public.xp_events enable row level security;

revoke all on public.users, public.trackers, public.tracker_access, public.progress,
  public.tasks, public.task_resources, public.task_progress, public.xp_events from anon;
revoke insert, update, delete on public.users, public.trackers, public.tracker_access, public.progress,
  public.tasks, public.task_resources, public.task_progress, public.xp_events from authenticated;
grant select on public.users, public.trackers, public.tracker_access, public.progress,
  public.tasks, public.task_resources, public.task_progress, public.xp_events to authenticated;

grant update (display_name, timezone) on public.users to authenticated;
grant update (name, description, icon, sort_order) on public.trackers to authenticated;
grant insert (tracker_id, parent_id, kind, title, description, xp, difficulty, week_number, time_estimate, sort_order, archived_at)
  on public.tasks to authenticated;
grant update (parent_id, kind, title, description, xp, difficulty, week_number, time_estimate, sort_order, archived_at)
  on public.tasks to authenticated;
grant insert (task_id, title, url, sort_order), delete on public.task_resources to authenticated;
grant update (title, url, sort_order) on public.task_resources to authenticated;

create policy users_select_own on public.users for select to authenticated
  using (id = auth.uid());
create policy users_update_own on public.users for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

create policy trackers_select on public.trackers for select to authenticated
  using (public.pt_tracker_role(id) is not null or public.pt_is_creator(id));
create policy trackers_update_creator on public.trackers for update to authenticated
  using (public.pt_is_creator(id)) with check (public.pt_is_creator(id));

create policy tracker_access_select on public.tracker_access for select to authenticated
  using ((user_id = auth.uid() and public.pt_is_approved()) or public.pt_is_creator(tracker_id));

create policy progress_select_own on public.progress for select to authenticated
  using (user_id = auth.uid() and public.pt_tracker_role(tracker_id) is not null);

create policy tasks_select on public.tasks for select to authenticated
  using (public.pt_tracker_role(tracker_id) is not null or public.pt_is_creator(tracker_id));
create policy tasks_insert_creator on public.tasks for insert to authenticated
  with check (public.pt_is_creator(tracker_id));
create policy tasks_update_creator on public.tasks for update to authenticated
  using (public.pt_is_creator(tracker_id)) with check (public.pt_is_creator(tracker_id));

create policy task_resources_select on public.task_resources for select to authenticated
  using (exists (select 1 from public.tasks t where t.id = task_id
    and (public.pt_tracker_role(t.tracker_id) is not null or public.pt_is_creator(t.tracker_id))));
create policy task_resources_insert_creator on public.task_resources for insert to authenticated
  with check (exists (select 1 from public.tasks t where t.id = task_id and public.pt_is_creator(t.tracker_id)));
create policy task_resources_update_creator on public.task_resources for update to authenticated
  using (exists (select 1 from public.tasks t where t.id = task_id and public.pt_is_creator(t.tracker_id)))
  with check (exists (select 1 from public.tasks t where t.id = task_id and public.pt_is_creator(t.tracker_id)));
create policy task_resources_delete_creator on public.task_resources for delete to authenticated
  using (exists (select 1 from public.tasks t where t.id = task_id and public.pt_is_creator(t.tracker_id)));

create policy task_progress_select on public.task_progress for select to authenticated
  using ((user_id = auth.uid() and public.pt_tracker_role(tracker_id) is not null)
    or public.pt_tracker_role(tracker_id) = 'guardian');

create policy xp_events_select on public.xp_events for select to authenticated
  using ((user_id = auth.uid() and public.pt_is_approved())
    or public.pt_tracker_role(tracker_id) = 'guardian');

-- =====================================================================
-- Internal helpers (not callable from the browser)
-- =====================================================================
create or replace function public.pt__user_today(p_user uuid) returns date
language sql stable security definer set search_path = public as $$
  select (now() at time zone coalesce((select timezone from public.users where id = p_user), 'UTC'))::date;
$$;

create or replace function public.pt__life_xp(p_user uuid) returns int
language sql stable security definer set search_path = public as $$
  select coalesce(sum(amount), 0)::int from public.xp_events where user_id = p_user;
$$;

create or replace function public.pt__streak(p_user uuid) returns int
language plpgsql stable security definer set search_path = public as $$
declare
  tz text;
  d date;
  n int := 0;
begin
  select coalesce(timezone, 'UTC') into tz from public.users where id = p_user;
  tz := coalesce(tz, 'UTC');
  d := (now() at time zone tz)::date;
  -- Today without activity yet does not break the streak.
  if not exists (select 1 from public.task_progress
                 where user_id = p_user and status = 'approved'
                   and (completed_at at time zone tz)::date = d) then
    d := d - 1;
  end if;
  while exists (select 1 from public.task_progress
                where user_id = p_user and status = 'approved'
                  and (completed_at at time zone tz)::date = d) loop
    n := n + 1;
    d := d - 1;
  end loop;
  return n;
end $$;

create or replace function public.pt__best_streak(p_user uuid) returns int
language sql stable security definer set search_path = public as $$
  with tz as (select coalesce((select timezone from public.users where id = p_user), 'UTC') as z),
  days as (
    select distinct (tp.completed_at at time zone (select z from tz))::date as d
    from public.task_progress tp
    where tp.user_id = p_user and tp.status = 'approved'),
  runs as (select d - (row_number() over (order by d))::int as grp from days)
  select coalesce(max(c), 0)::int from (select count(*) as c from runs group by grp) x;
$$;

create or replace function public.pt__godot_phase_done(p_user uuid, p_tracker uuid, p_seed text) returns boolean
language sql stable security definer set search_path = public as $$
  with phase as (select id from public.tasks where tracker_id = p_tracker and seed_key = p_seed)
  select exists (select 1 from phase)
    and not exists (
      select 1 from public.tasks t
      where t.parent_id = (select id from phase)
        and t.kind = 'task' and t.archived_at is null
        and not exists (select 1 from public.task_progress tp
                        where tp.task_id = t.id and tp.user_id = p_user and tp.status = 'approved'));
$$;

-- Godot rules, unchanged from the original page: the level threshold is
-- captured once before looping, and achievement XP adds to total XP only.
create or replace function public.pt__godot_apply(p_user uuid, p_tracker uuid, p_xp int) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  p public.progress;
  lvl int;
  start_level int;
  cur int;
  total int;
  threshold int;
  done_count int;
  task_count int;
  completion int;
  unlocked text[];
  new_achievements text[] := '{}';
  a record;
  ok boolean;
begin
  insert into public.progress (tracker_id, user_id) values (p_tracker, p_user)
  on conflict (tracker_id, user_id) do nothing;
  select * into p from public.progress where tracker_id = p_tracker and user_id = p_user for update;

  lvl := coalesce(p.level, 1);
  start_level := lvl;
  cur := coalesce(p.current_xp, 0) + p_xp;
  total := coalesce(p.total_xp, 0) + p_xp;
  threshold := 100 * lvl;
  while cur >= threshold loop
    lvl := lvl + 1;
    cur := cur - threshold;
  end loop;

  select count(*) filter (where tp.status = 'approved'), count(*)
    into done_count, task_count
  from public.tasks t
  left join public.task_progress tp on tp.task_id = t.id and tp.user_id = p_user
  where t.tracker_id = p_tracker and t.kind = 'task' and t.archived_at is null;
  completion := case when task_count = 0 then 0 else round(done_count * 100.0 / task_count)::int end;

  unlocked := coalesce(p.unlocked_achievements, '{}');
  for a in select * from (values
      ('a1', 50, 1), ('a2', 50, 2), ('a3', 100, 3), ('a4', 100, 4), ('a5', 50, 5), ('a6', 200, 6)
    ) v(id, xp, ord) order by ord
  loop
    continue when a.id = any(unlocked);
    ok := case a.id
      when 'a1' then done_count >= 3
      when 'a2' then public.pt__godot_phase_done(p_user, p_tracker, 'godot:phase:player')
      when 'a3' then public.pt__godot_phase_done(p_user, p_tracker, 'godot:phase:combat')
      when 'a4' then public.pt__godot_phase_done(p_user, p_tracker, 'godot:phase:polish')
      when 'a5' then completion >= 25
      when 'a6' then completion = 100
    end;
    if ok then
      unlocked := array_append(unlocked, a.id);
      new_achievements := array_append(new_achievements, a.id);
      total := total + a.xp;
      insert into public.xp_events (user_id, tracker_id, amount, reason, note, occurred_on)
      values (p_user, p_tracker, a.xp, 'achievement', a.id, public.pt__user_today(p_user));
    end if;
  end loop;

  update public.progress
  set level = lvl, current_xp = cur, total_xp = total,
      unlocked_achievements = unlocked, updated_at = now()
  where id = p.id;

  return jsonb_build_object(
    'level', lvl, 'current_xp', cur, 'total_xp', total,
    'unlocked_achievements', to_jsonb(unlocked),
    'unlocked_skills', to_jsonb(coalesce(p.unlocked_skills, '{}')),
    'new_achievements', to_jsonb(new_achievements),
    'leveled_up', lvl > start_level);
end $$;

create or replace function public.pt__award(p_progress uuid, p_approver uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  pr public.task_progress;
  t public.tasks;
  tr public.trackers;
  tz text;
  res jsonb;
begin
  select * into pr from public.task_progress where id = p_progress for update;
  if not found or pr.status <> 'pending' then
    raise exception 'This completion is not waiting for review';
  end if;
  select * into t from public.tasks where id = pr.task_id;
  select * into tr from public.trackers where id = pr.tracker_id;
  select coalesce(timezone, 'UTC') into tz from public.users where id = pr.user_id;

  update public.task_progress
  set status = 'approved', awarded_xp = t.xp, approved_by = p_approver,
      approved_at = now(), updated_at = now()
  where id = pr.id;

  if t.xp <> 0 then
    insert into public.xp_events (user_id, tracker_id, task_id, amount, reason, occurred_on)
    values (pr.user_id, tr.id, t.id, t.xp, 'task', (pr.completed_at at time zone coalesce(tz, 'UTC'))::date);
  end if;

  res := jsonb_build_object('status', 'approved', 'changed', true, 'awarded_xp', t.xp);
  if tr.ruleset = 'godot' then
    res := res || jsonb_build_object('godot', public.pt__godot_apply(pr.user_id, tr.id, t.xp));
  end if;
  return res;
end $$;

create or replace function public.pt__progress_access(p_user uuid, p_tracker uuid) returns text
language plpgsql stable security definer set search_path = public as $$
declare
  r text;
  editable boolean;
begin
  select a.role, coalesce(a.can_edit, true) into r, editable
  from public.tracker_access a
  where a.tracker_id = p_tracker and a.user_id = p_user;
  if r is null or r not in ('owner', 'member') or not editable
     or not exists (select 1 from public.users where id = p_user) then
    raise exception 'You cannot update progress on this tracker' using errcode = '42501';
  end if;
  return r;
end $$;

create or replace function public.pt__complete(p_user uuid, p_task uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  t public.tasks;
  tr public.trackers;
  r text;
  pr public.task_progress;
begin
  select * into t from public.tasks where id = p_task;
  if not found or t.kind <> 'task' or t.archived_at is not null then
    raise exception 'That task is not available' using errcode = 'P0002';
  end if;
  select * into tr from public.trackers where id = t.tracker_id;
  r := public.pt__progress_access(p_user, tr.id);

  -- Serialises a user's writes per tracker so double clicks cannot double-award.
  perform pg_advisory_xact_lock(hashtextextended(p_user::text || tr.id::text, 0));

  select * into pr from public.task_progress where user_id = p_user and task_id = p_task;
  if found and pr.status in ('approved', 'pending') then
    return jsonb_build_object('status', pr.status, 'changed', false);
  end if;

  if found then
    update public.task_progress
    set status = 'pending', completed_at = now(), awarded_xp = null,
        approved_by = null, approved_at = null, updated_at = now()
    where id = pr.id
    returning * into pr;
  else
    insert into public.task_progress (tracker_id, task_id, user_id, status)
    values (tr.id, p_task, p_user, 'pending')
    returning * into pr;
  end if;

  if tr.requires_approval and r = 'member' then
    return jsonb_build_object('status', 'pending', 'changed', true);
  end if;
  return public.pt__award(pr.id, p_user);
end $$;

-- =====================================================================
-- Browser-callable functions
-- =====================================================================
create or replace function public.pt_me() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me public.users;
begin
  if auth.uid() is null then
    raise exception 'Not signed in' using errcode = '28000';
  end if;
  select * into me from public.users where id = auth.uid();
  if not found then
    return jsonb_build_object('approved', false, 'email', auth.jwt() ->> 'email');
  end if;
  return jsonb_build_object('approved', true, 'id', me.id, 'email', me.email,
    'display_name', me.display_name, 'timezone', me.timezone);
end $$;

create or replace function public.pt_complete_task(p_task uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'Not signed in' using errcode = '28000';
  end if;
  return public.pt__complete(auth.uid(), p_task);
end $$;

create or replace function public.pt_uncomplete_task(p_task uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  t public.tasks;
  tr public.trackers;
  pr public.task_progress;
begin
  select * into t from public.tasks where id = p_task;
  if not found then
    raise exception 'That task is not available' using errcode = 'P0002';
  end if;
  select * into tr from public.trackers where id = t.tracker_id;
  perform public.pt__progress_access(uid, tr.id);
  perform pg_advisory_xact_lock(hashtextextended(uid::text || tr.id::text, 0));

  select * into pr from public.task_progress where user_id = uid and task_id = p_task;
  if not found then
    return jsonb_build_object('status', 'none', 'changed', false);
  end if;
  -- Withdrawing a pending submission is always allowed; awarded XP only where unchecking is enabled.
  if pr.status = 'approved' and not tr.allow_uncheck then
    raise exception 'Completed tasks in this tracker cannot be unchecked';
  end if;

  delete from public.task_progress where id = pr.id;
  if pr.status = 'approved' and coalesce(pr.awarded_xp, 0) <> 0 then
    insert into public.xp_events (user_id, tracker_id, task_id, amount, reason, occurred_on)
    values (uid, tr.id, t.id, -pr.awarded_xp, 'refund', public.pt__user_today(uid));
  end if;
  return jsonb_build_object('status', 'none', 'changed', true,
    'refunded_xp', case when pr.status = 'approved' then coalesce(pr.awarded_xp, 0) else 0 end);
end $$;

create or replace function public.pt_review_completion(p_progress uuid, p_approve boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  pr public.task_progress;
begin
  select * into pr from public.task_progress where id = p_progress;
  if not found or coalesce(public.pt_tracker_role(pr.tracker_id), '') <> 'guardian' then
    raise exception 'You cannot review this completion' using errcode = '42501';
  end if;
  if pr.status <> 'pending' then
    raise exception 'This completion was already reviewed';
  end if;
  if p_approve then
    return public.pt__award(pr.id, auth.uid());
  end if;
  update public.task_progress
  set status = 'rejected', approved_by = auth.uid(), approved_at = now(), updated_at = now()
  where id = pr.id;
  return jsonb_build_object('status', 'rejected', 'changed', true);
end $$;

create or replace function public.pt_godot_unlock_skill(p_tracker uuid, p_skill text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  cost int;
  p public.progress;
begin
  perform public.pt__progress_access(uid, p_tracker);
  if not exists (select 1 from public.trackers where id = p_tracker and ruleset = 'godot') then
    raise exception 'Skills are only available on the Godot tracker';
  end if;
  cost := case p_skill when 's1' then 300 when 's2' then 500 when 's3' then 1000 end;
  if cost is null then
    raise exception 'Unknown skill';
  end if;
  select * into p from public.progress where tracker_id = p_tracker and user_id = uid for update;
  if not found or p.total_xp < cost then
    raise exception 'Not enough XP for this skill';
  end if;
  if not (p_skill = any(p.unlocked_skills)) then
    update public.progress set unlocked_skills = array_append(unlocked_skills, p_skill), updated_at = now()
    where id = p.id returning * into p;
  end if;
  return jsonb_build_object('unlocked_skills', to_jsonb(p.unlocked_skills));
end $$;

create or replace function public.pt_reset_tracker(p_tracker uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  net int;
begin
  perform public.pt__progress_access(uid, p_tracker);
  perform pg_advisory_xact_lock(hashtextextended(uid::text || p_tracker::text, 0));
  delete from public.task_progress where user_id = uid and tracker_id = p_tracker;
  select coalesce(sum(amount), 0) into net from public.xp_events where user_id = uid and tracker_id = p_tracker;
  if net <> 0 then
    insert into public.xp_events (user_id, tracker_id, amount, reason, occurred_on)
    values (uid, p_tracker, -net, 'reset', public.pt__user_today(uid));
  end if;
  update public.progress
  set level = 1, current_xp = 0, total_xp = 0, unlocked_achievements = '{}',
      unlocked_skills = '{}', updated_at = now()
  where user_id = uid and tracker_id = p_tracker;
  return jsonb_build_object('removed_xp', net);
end $$;

-- Imports completions saved by the old browser-only pages. Keys are legacy
-- IDs (Godot "t1", career "item-0-0-0") or task UUIDs. Safe to repeat.
create or replace function public.pt_import_completions(p_tracker uuid, p_keys text[]) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  k text;
  tid uuid;
  res jsonb;
  imported int := 0;
  already int := 0;
  unknown text[] := '{}';
begin
  perform public.pt__progress_access(uid, p_tracker);
  if coalesce(array_length(p_keys, 1), 0) > 1000 then
    raise exception 'Too many items to import at once';
  end if;
  for k in select distinct unnest(p_keys) loop
    tid := null;
    select id into tid from public.tasks
    where tracker_id = p_tracker and kind = 'task' and archived_at is null
      and (legacy_key = k or id::text = k)
    limit 1;
    if tid is null then
      unknown := array_append(unknown, left(k, 60));
      continue;
    end if;
    res := public.pt__complete(uid, tid);
    if (res ->> 'changed')::boolean then imported := imported + 1; else already := already + 1; end if;
  end loop;
  return jsonb_build_object('imported', imported, 'already', already, 'unknown', to_jsonb(unknown));
end $$;

create or replace function public.pt_dashboard() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  me public.users;
  today date;
begin
  if uid is null then
    raise exception 'Not signed in' using errcode = '28000';
  end if;
  select * into me from public.users where id = uid;
  if not found then
    return jsonb_build_object('approved', false, 'email', auth.jwt() ->> 'email');
  end if;
  today := public.pt__user_today(uid);

  return jsonb_build_object(
    'approved', true,
    'user', jsonb_build_object('id', uid, 'email', me.email, 'display_name', me.display_name, 'timezone', me.timezone),
    'life_xp', public.pt__life_xp(uid),
    'streak', public.pt__streak(uid),
    'best_streak', public.pt__best_streak(uid),
    'tasks_done', (select count(*) from public.task_progress where user_id = uid and status = 'approved'),
    'today_xp', (select coalesce(sum(amount), 0) from public.xp_events
                 where user_id = uid and occurred_on = today and reason in ('task', 'achievement')),
    'week', (
      select jsonb_agg(jsonb_build_object('date', d::date, 'done', exists (
               select 1 from public.task_progress tp
               where tp.user_id = uid and tp.status = 'approved'
                 and (tp.completed_at at time zone me.timezone)::date = d::date)) order by d)
      from generate_series((today - 6)::timestamp, today::timestamp, interval '1 day') d),
    'is_creator', exists (select 1 from public.trackers where created_by = uid),
    'trackers', (
      select coalesce(jsonb_agg(to_jsonb(x) order by x.sort_order, x.name), '[]'::jsonb) from (
        select t.id, t.slug, t.name, t.description, t.page, t.icon, t.sort_order,
               a.role, coalesce(a.can_edit, true) as can_edit, (t.created_by = uid) as is_creator, t.requires_approval,
               (select count(*) from public.tasks k where k.tracker_id = t.id and k.kind = 'task' and k.archived_at is null) as total_tasks,
               (select count(*) from public.task_progress tp join public.tasks k on k.id = tp.task_id
                 where tp.tracker_id = t.id and tp.user_id = uid and tp.status = 'approved' and k.archived_at is null) as done_tasks,
               (select count(*) from public.task_progress tp where tp.tracker_id = t.id and tp.user_id = uid and tp.status = 'pending') as my_pending,
               (select coalesce(sum(e.amount), 0) from public.xp_events e where e.tracker_id = t.id and e.user_id = uid) as xp,
               (select count(*) from public.task_progress tp where tp.tracker_id = t.id and tp.user_id <> uid and tp.status = 'pending' and a.role = 'guardian') as to_review,
               (select jsonb_build_object('id', k.id, 'title', k.title, 'xp', k.xp)
                  from public.tasks k
                  left join public.tasks pk on pk.id = k.parent_id
                  where k.tracker_id = t.id and k.kind = 'task' and k.archived_at is null
                    and (pk.id is null or pk.archived_at is null)
                    and not exists (select 1 from public.task_progress tp
                                    where tp.task_id = k.id and tp.user_id = uid and tp.status in ('approved', 'pending'))
                  order by coalesce(k.week_number, 0), coalesce(pk.sort_order, 0), k.sort_order, k.created_at
                  limit 1) as next_task
        from public.trackers t
        join public.tracker_access a on a.tracker_id = t.id and a.user_id = uid
      ) x),
    'recent', (
      select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc), '[]'::jsonb) from (
        select e.amount, e.reason, e.note, e.created_at, t.name as tracker_name, k.title as task_title
        from public.xp_events e
        join public.trackers t on t.id = e.tracker_id
        left join public.tasks k on k.id = e.task_id
        where e.user_id = uid
        order by e.created_at desc
        limit 15
      ) x),
    'approvals', (
      select coalesce(jsonb_agg(to_jsonb(x) order by x.completed_at), '[]'::jsonb) from (
        select tp.id, tp.completed_at, k.title as task_title, k.xp, t.name as tracker_name,
               coalesce(u.display_name, u.email) as user_name
        from public.task_progress tp
        join public.tracker_access a on a.tracker_id = tp.tracker_id and a.user_id = uid and a.role = 'guardian'
        join public.tasks k on k.id = tp.task_id
        join public.trackers t on t.id = tp.tracker_id
        left join public.users u on u.id = tp.user_id
        where tp.status = 'pending' and tp.user_id <> uid
        order by tp.completed_at
        limit 50
      ) x),
    'family', (
      select coalesce(jsonb_agg(to_jsonb(x) order by x.name), '[]'::jsonb) from (
        select m.user_id as id, coalesce(u.display_name, u.email) as name,
               public.pt__life_xp(m.user_id) as life_xp, public.pt__streak(m.user_id) as streak,
               (select count(*) from public.task_progress tp where tp.user_id = m.user_id and tp.status = 'pending'
                  and tp.tracker_id in (select tracker_id from public.tracker_access where user_id = uid and role = 'guardian')) as pending
        from (select distinct am.user_id
              from public.tracker_access ag
              join public.tracker_access am on am.tracker_id = ag.tracker_id and am.role = 'member' and am.user_id <> uid
              where ag.user_id = uid and ag.role = 'guardian') m
        left join public.users u on u.id = m.user_id
      ) x)
  );
end $$;

-- =====================================================================
-- Admin functions: run from the SQL Editor only (never from the browser)
-- =====================================================================
create or replace function public.pt_admin_approve_user(p_email text, p_display_name text default null, p_timezone text default 'UTC')
returns uuid language plpgsql security definer set search_path = public as $$
declare
  uid uuid;
begin
  select id into uid from auth.users where lower(email) = lower(p_email);
  if uid is null then
    raise exception 'No account for %. Ask them to sign in once first, then run this again.', p_email;
  end if;
  insert into public.users (id, email, display_name, timezone)
  values (uid, lower(p_email), p_display_name, coalesce(p_timezone, 'UTC'))
  on conflict (id) do update set display_name = coalesce(excluded.display_name, public.users.display_name);
  return uid;
end $$;

create or replace function public.pt_admin_create_tracker(
  p_slug text, p_name text, p_description text, p_creator_email text,
  p_ruleset text default 'standard', p_page text default null, p_icon text default 'target',
  p_requires_approval boolean default false, p_allow_uncheck boolean default true)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  tid uuid;
  uid uuid;
begin
  select id into tid from public.trackers where slug = p_slug;
  if tid is not null then
    return tid;
  end if;
  select id into uid from public.users where lower(email) = lower(p_creator_email);
  if uid is null then
    raise exception 'Approve % first with pt_admin_approve_user', p_creator_email;
  end if;
  insert into public.trackers (slug, name, description, created_by, ruleset, page, icon, requires_approval, allow_uncheck)
  values (p_slug, p_name, p_description, uid, p_ruleset, p_page, p_icon, p_requires_approval,
          case when p_ruleset = 'godot' then false else p_allow_uncheck end)
  returning id into tid;
  insert into public.tracker_access (tracker_id, user_id, role, can_edit)
  values (tid, uid, case when p_requires_approval then 'guardian' else 'owner' end, true)
  on conflict (tracker_id, user_id) do nothing;
  return tid;
end $$;

-- Attaches a slug and page to a tracker that already exists in the database.
create or replace function public.pt_admin_link_tracker(
  p_tracker uuid, p_slug text, p_page text, p_ruleset text default 'standard', p_icon text default 'target')
returns uuid language plpgsql security definer set search_path = public as $$
begin
  update public.trackers
  set slug = p_slug, page = p_page, ruleset = p_ruleset, icon = p_icon,
      allow_uncheck = case when p_ruleset = 'godot' then false else allow_uncheck end
  where id = p_tracker and (slug is null or slug = p_slug);
  if not found then
    raise exception 'Tracker % not found, or it already has a different slug', p_tracker;
  end if;
  update public.tracker_access a set role = 'owner'
  from public.trackers t
  where t.id = a.tracker_id and t.id = p_tracker and a.user_id = t.created_by and a.role = 'member';
  return p_tracker;
end $$;

create or replace function public.pt_admin_grant(p_slug text, p_email text, p_role text, p_can_edit boolean default true)
returns void language plpgsql security definer set search_path = public as $$
declare
  tid uuid;
  uid uuid;
begin
  select id into tid from public.trackers where slug = p_slug;
  select id into uid from public.users where lower(email) = lower(p_email);
  if tid is null or uid is null then
    raise exception 'Tracker % or approved user % not found', p_slug, p_email;
  end if;
  insert into public.tracker_access (tracker_id, user_id, role, can_edit)
  values (tid, uid, p_role, p_can_edit)
  on conflict (tracker_id, user_id) do update set role = excluded.role, can_edit = excluded.can_edit;
end $$;

create or replace function public.pt__seed_node(
  p_tracker uuid, p_seed text, p_parent_seed text, p_kind text, p_title text,
  p_xp int, p_difficulty text, p_week int, p_time text, p_sort int, p_legacy text)
returns void language plpgsql security definer set search_path = public as $$
begin
  insert into public.tasks (tracker_id, parent_id, kind, title, xp, difficulty, week_number, time_estimate, sort_order, seed_key, legacy_key)
  values (p_tracker,
          (select id from public.tasks where tracker_id = p_tracker and seed_key = p_parent_seed),
          p_kind, p_title, coalesce(p_xp, 0), p_difficulty, p_week, p_time, p_sort, p_seed, p_legacy)
  on conflict (tracker_id, seed_key) do nothing;
end $$;

create or replace function public.pt__seed_resource(p_tracker uuid, p_node_seed text, p_title text, p_url text, p_sort int)
returns void language plpgsql security definer set search_path = public as $$
begin
  insert into public.task_resources (task_id, title, url, sort_order)
  select id, p_title, p_url, p_sort from public.tasks where tracker_id = p_tracker and seed_key = p_node_seed
  on conflict (task_id, url) do nothing;
end $$;

-- Adds the built-in task lists. Existing rows (including your edits) are left alone.
create or replace function public.pt_admin_seed(p_slug text, p_template text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  tid uuid;
  tmpl text := coalesce(p_template, p_slug);
  r record;
  before_count int;
begin
  select id into tid from public.trackers where slug = p_slug;
  if tid is null then
    raise exception 'Tracker % not found', p_slug;
  end if;
  select count(*) into before_count from public.tasks where tracker_id = tid;

  if tmpl = 'godot' then
    for r in select * from (values
        ('setup', 'Setup & Foundations', 1), ('player', 'Player Control', 2), ('combat', 'Combat System', 3),
        ('menu', 'Menu & State System', 4), ('polish', 'Polish', 5), ('extra', 'Optional Features', 6)
      ) v(key, title, ord)
    loop
      perform public.pt__seed_node(tid, 'godot:phase:' || r.key, null, 'phase', r.title, 0, null, null, null, r.ord * 10, null);
    end loop;
    for r in select * from (values
        ('setup', 't1', 'Install Godot 4.x & .NET SDK', 15, 1),
        ('setup', 't2', 'Create new C# Godot project', 20, 2),
        ('setup', 't3', 'Set up project structure & Git', 25, 3),
        ('setup', 't4', 'First scene: empty 2D stage', 15, 4),
        ('player', 't5', 'Player sprite & animation setup', 25, 1),
        ('player', 't6', 'WASD movement controller', 30, 2),
        ('player', 't7', 'Camera follow player', 20, 3),
        ('player', 't8', 'Collision detection working', 25, 4),
        ('combat', 't9', 'Attack animation & slash hitbox', 35, 1),
        ('combat', 't10', 'Basic enemy prefab', 30, 2),
        ('combat', 't11', 'Enemy health & damage system', 30, 3),
        ('combat', 't12', 'Enemy knockback on hit', 25, 4),
        ('combat', 't13', 'Simple AI (walk + attack)', 40, 5),
        ('menu', 't14', 'Main menu with Play/Exit buttons', 30, 1),
        ('menu', 't14b', 'Animated background for menu', 25, 2),
        ('menu', 't14c', 'Save/Load game state system', 40, 3),
        ('menu', 't14d', 'Menu transitions & animations', 20, 4),
        ('polish', 't15', 'Health bar UI (player & enemies)', 25, 1),
        ('polish', 't16', 'Game over & restart', 20, 2),
        ('polish', 't17', 'Sound effects (attack, hit, death)', 30, 3),
        ('polish', 't18', 'Particle effects on slash', 30, 4),
        ('extra', 't19', 'Enemy spawner waves', 35, 1),
        ('extra', 't20', '2-3 attack combo system', 40, 2),
        ('extra', 't21', 'Simple score/wave system', 25, 3),
        ('extra', 't22', 'Enemy variety (2+ types)', 40, 4)
      ) v(phase, legacy, title, xp, ord)
    loop
      perform public.pt__seed_node(tid, 'godot:' || r.legacy, 'godot:phase:' || r.phase, 'task', r.title, r.xp, null, null, null, r.ord * 10, r.legacy);
    end loop;

  elsif tmpl = 'career-pivot' then
    for r in select * from (values
        (1, 'Azure Refresh + Docker Setup', '12-14 hrs'),
        (2, 'Docker Deep Dive + Container Instances', '13-15 hrs'),
        (3, 'Project 1: Weather Pipeline (Build Phase)', '14-15 hrs'),
        (4, 'Project 1: Deploy + Blog', '12-14 hrs'),
        (5, 'Azure OpenAI + FastAPI Basics', '13-15 hrs'),
        (6, 'Project 2: Document Analyzer (Build Phase)', '14-15 hrs'),
        (7, 'Project 2: Deploy + Frontend', '14-15 hrs'),
        (8, 'AI-200 Exam Prep Sprint 1', '12-14 hrs'),
        (9, 'Azure ML + Model Training', '14-15 hrs'),
        (10, 'ML Pipeline Orchestration', '13-15 hrs'),
        (11, 'Project 3: Deploy + Monitoring', '14-15 hrs'),
        (12, 'AI-200 Exam Sprint 2 + Career Prep', '13-15 hrs')
      ) v(week, title, est)
    loop
      perform public.pt__seed_node(tid, 'career:w' || r.week, null, 'week', r.title, 0, null, r.week, r.est, r.week * 10, null);
      perform public.pt__seed_node(tid, 'career:w' || r.week || ':s0', 'career:w' || r.week, 'section', 'Tasks', 0, null, r.week, null, 10, null);
    end loop;
    for r in select * from (values
        (4, 'Phase 1 Complete: Project 1 Live on Azure'),
        (8, 'Phase 2 Complete: Project 2 Live + AI-200 Prep Started'),
        (12, 'Phase 3 Complete: All Projects Live + AI-200 Ready')
      ) v(week, title)
    loop
      perform public.pt__seed_node(tid, 'career:divider:' || r.week, null, 'divider', r.title, 0, null, r.week, null, r.week * 10 + 5, null);
    end loop;
    -- Legacy keys reproduce the old page's positional IDs: dividers occupied array slots 4, 9 and 14.
    for r in select * from (values
        (1, 0, 'Refresh: Azure Portal navigation, Resource Groups, Subscriptions', 'easy'),
        (1, 1, 'Refresh: VMs, Storage Accounts, App Service basics', 'easy'),
        (1, 2, 'Docker: Install Docker Desktop', 'easy'),
        (1, 3, 'Docker: Run ''hello-world'' container', 'easy'),
        (1, 4, 'Docker: Build first Dockerfile (simple Python app)', 'medium'),
        (2, 0, 'Docker: Multi-stage builds & best practices', 'medium'),
        (2, 1, 'Docker: Push image to Docker Hub', 'medium'),
        (2, 2, 'Azure: Set up Container Registry (ACR)', 'medium'),
        (2, 3, 'Azure: Deploy to Container Instances (ACI)', 'medium'),
        (2, 4, 'Azure: Configure networking & environment variables', 'medium'),
        (3, 0, 'Setup: Create GitHub repo + Python project skeleton', 'easy'),
        (3, 1, 'Code: Weather API integration (OpenWeatherMap or similar)', 'medium'),
        (3, 2, 'Code: Data pipeline (fetch → transform → store)', 'medium'),
        (3, 3, 'Storage: Set up Azure Blob Storage container', 'easy'),
        (3, 4, 'Code: Local testing & debugging', 'medium'),
        (4, 0, 'Docker: Containerize weather pipeline', 'medium'),
        (4, 1, 'Deploy: Push to ACR', 'easy'),
        (4, 2, 'Deploy: Run on ACI with schedule/timer', 'medium'),
        (4, 3, 'GitHub: Polish README + documentation', 'medium'),
        (4, 4, 'Blog: Write ''Deploying Weather Pipeline to Azure'' post', 'medium'),
        (5, 0, 'Azure: Request & setup Azure OpenAI Service access', 'medium'),
        (5, 1, 'Azure: Deploy GPT-4 or Claude model', 'easy'),
        (5, 2, 'FastAPI: Install & run ''Hello World'' app', 'easy'),
        (5, 3, 'FastAPI: Create first endpoint (GET, POST)', 'medium'),
        (5, 4, 'Integration: Call Azure OpenAI from FastAPI', 'medium'),
        (5, 5, 'Testing: Local testing with curl/Postman', 'medium'),
        (6, 0, 'Setup: Create new GitHub repo for Project 2', 'easy'),
        (6, 1, 'Backend: File upload endpoint (FastAPI + Python-Multipart)', 'medium'),
        (6, 2, 'Backend: Document parsing (PDF/TXT extraction)', 'hard'),
        (6, 3, 'Backend: Call Azure OpenAI for analysis', 'medium'),
        (6, 4, 'Backend: Return structured response (JSON)', 'medium'),
        (6, 5, 'Testing: End-to-end test locally', 'medium'),
        (7, 0, 'Frontend: Build simple React upload form (or Vue)', 'hard'),
        (7, 1, 'Frontend: Call backend API from React', 'medium'),
        (7, 2, 'Frontend: Display analysis results', 'medium'),
        (7, 3, 'Deploy: Push code to GitHub', 'easy'),
        (7, 4, 'Deploy: Create Dockerfile for full app', 'medium'),
        (7, 5, 'Deploy: Push to ACR + Deploy to Azure App Service', 'medium'),
        (8, 0, 'Study: Review AI-200 exam objectives & study guide', 'medium'),
        (8, 1, 'Study: Azure AI Services overview (all services)', 'hard'),
        (8, 2, 'Practice: Take first AI-200 practice exam (full)', 'hard'),
        (8, 3, 'Review: Identify weak areas from practice test', 'medium'),
        (8, 4, 'Blog: Write ''Building AI Apps with Azure OpenAI'' post', 'medium'),
        (9, 0, 'Azure ML: Set up workspace & compute instance', 'medium'),
        (9, 1, 'ML: Prepare dataset (housing, sales, or classification data)', 'medium'),
        (9, 2, 'ML: Exploratory Data Analysis (EDA) with pandas', 'medium'),
        (9, 3, 'ML: Feature engineering & preprocessing', 'hard'),
        (9, 4, 'ML: Train model (scikit-learn or AutoML)', 'medium'),
        (9, 5, 'ML: Evaluate model performance (metrics, validation)', 'medium'),
        (10, 0, 'ML: Create inference script (model predictions)', 'medium'),
        (10, 1, 'ML: Build FastAPI endpoint for predictions', 'medium'),
        (10, 2, 'ML: Create Azure ML pipeline (data → train → evaluate)', 'hard'),
        (10, 3, 'ML: Set up model registry & versioning', 'medium'),
        (10, 4, 'ML: Document pipeline architecture', 'medium'),
        (11, 0, 'Deploy: Create Azure ML endpoint for model', 'hard'),
        (11, 1, 'Deploy: Test endpoint (predictions working)', 'medium'),
        (11, 2, 'Monitor: Set up Application Insights logging', 'medium'),
        (11, 3, 'Deploy: Containerize entire ML app', 'medium'),
        (11, 4, 'GitHub: Push all code + comprehensive README', 'medium'),
        (11, 5, 'Documentation: Write ML ops workflow guide', 'medium'),
        (12, 0, 'Study: Practice exam 2 (focus on weak areas)', 'hard'),
        (12, 1, 'Study: Deep dive on Azure Cognitive Services', 'hard'),
        (12, 2, 'Study: Review real-world ML scenarios & best practices', 'hard'),
        (12, 3, 'Exam: Schedule AI-200 exam date (within 2 weeks)', 'easy'),
        (12, 4, 'Career: Polish resume with 3 projects + AI-200 target', 'medium'),
        (12, 5, 'Career: Update LinkedIn with projects & certification goal', 'easy'),
        (12, 6, 'Career: Write final blog post (3 projects overview)', 'medium'),
        (12, 7, 'Career: Start applying to Cloud/AI roles', 'medium')
      ) v(week, idx, title, difficulty)
    loop
      perform public.pt__seed_node(
        tid, 'career:w' || r.week || ':s0:i' || r.idx, 'career:w' || r.week || ':s0', 'task', r.title,
        case r.difficulty when 'easy' then 15 when 'medium' then 25 else 40 end,
        r.difficulty, r.week, null, (r.idx + 1) * 10,
        'item-' || (case when r.week <= 4 then r.week - 1 when r.week <= 8 then r.week else r.week + 1 end) || '-0-' || r.idx);
    end loop;
    for r in select * from (values
        (1, 1, 'Docker Get Started', 'https://docs.docker.com/get-started/'),
        (1, 2, 'Azure Portal Tour', 'https://learn.microsoft.com/en-us/azure/azure-portal/'),
        (2, 1, 'Docker Compose', 'https://docs.docker.com/compose/'),
        (2, 2, 'Azure Container Registry Docs', 'https://learn.microsoft.com/en-us/azure/container-registry/'),
        (2, 3, 'Container Instances Docs', 'https://learn.microsoft.com/en-us/azure/container-instances/'),
        (3, 1, 'Requests Library Docs', 'https://requests.readthedocs.io/'),
        (3, 2, 'Azure Storage SDK Python', 'https://learn.microsoft.com/en-us/python/api/overview/azure/storage'),
        (3, 3, 'GitHub Getting Started', 'https://docs.github.com/en/get-started'),
        (4, 1, 'Dev.to Writing Guide', 'https://dev.to/'),
        (4, 2, 'Markdown Guide', 'https://www.markdownguide.org/'),
        (4, 3, 'Azure Container Instances Scheduling', 'https://learn.microsoft.com/en-us/azure/container-instances/'),
        (5, 1, 'FastAPI Official Tutorial', 'https://fastapi.tiangolo.com/tutorial/'),
        (5, 2, 'Azure OpenAI Getting Started', 'https://learn.microsoft.com/en-us/azure/ai-services/openai/quickstart'),
        (5, 3, 'Azure OpenAI Python SDK', 'https://github.com/Azure/azure-sdk-for-python'),
        (6, 1, 'FastAPI File Upload', 'https://fastapi.tiangolo.com/tutorial/request-files/'),
        (6, 2, 'Python PDF Processing', 'https://pymupdf.readthedocs.io/'),
        (6, 3, 'JSON Best Practices', 'https://docs.python-guide.org/writing/style/'),
        (7, 1, 'React Official Tutorial', 'https://react.dev/learn'),
        (7, 2, 'Azure App Service Deployment', 'https://learn.microsoft.com/en-us/azure/app-service/'),
        (7, 3, 'CORS Configuration', 'https://fastapi.tiangolo.com/tutorial/cors/'),
        (8, 1, 'AI-200 Study Path', 'https://learn.microsoft.com/en-us/training/paths/prepare-for-azure-ai-engineer-certification/'),
        (8, 2, 'Azure AI Services Docs', 'https://learn.microsoft.com/en-us/azure/ai-services/'),
        (8, 3, 'Practice Exam', 'https://learn.microsoft.com/en-us/credentials/certifications/exams/ai-200/'),
        (9, 1, 'Azure ML Studio', 'https://ml.azure.com/'),
        (9, 2, 'Azure ML Documentation', 'https://learn.microsoft.com/en-us/azure/machine-learning/'),
        (9, 3, 'Scikit-learn Docs', 'https://scikit-learn.org/stable/'),
        (9, 4, 'Pandas Documentation', 'https://pandas.pydata.org/docs/'),
        (10, 1, 'Azure ML Pipelines', 'https://learn.microsoft.com/en-us/azure/machine-learning/concept-ml-pipelines'),
        (10, 2, 'MLflow Tracking', 'https://learn.microsoft.com/en-us/azure/machine-learning/how-to-use-mlflow'),
        (10, 3, 'Model Deployment Guide', 'https://learn.microsoft.com/en-us/azure/machine-learning/how-to-deploy-managed-online-endpoints'),
        (11, 1, 'Azure ML Endpoints', 'https://learn.microsoft.com/en-us/azure/machine-learning/how-to-deploy-managed-online-endpoints'),
        (11, 2, 'Application Insights', 'https://learn.microsoft.com/en-us/azure/azure-monitor/app/app-insights-overview'),
        (11, 3, 'GitHub README Best Practices', 'https://github.com/othneildrew/Best-README-Template'),
        (12, 1, 'AI-200 Exam Details', 'https://learn.microsoft.com/en-us/credentials/certifications/exams/ai-200/'),
        (12, 2, 'Pearson VUE Registration', 'https://www.pearsonvue.com/microsoft'),
        (12, 3, 'Job Boards: LinkedIn', 'https://www.linkedin.com/jobs/'),
        (12, 4, 'Tech Jobs: Stack Overflow', 'https://stackoverflow.com/jobs')
      ) v(week, ord, title, url)
    loop
      perform public.pt__seed_resource(tid, 'career:w' || r.week || ':s0', r.title, r.url, r.ord * 10);
    end loop;
  else
    raise exception 'Unknown template %; use godot or career-pivot', tmpl;
  end if;

  return jsonb_build_object('tracker', p_slug,
    'added', (select count(*) from public.tasks where tracker_id = tid) - before_count,
    'tasks', (select count(*) from public.tasks where tracker_id = tid and kind = 'task' and archived_at is null));
end $$;

-- Moves old aggregate Godot progress into per-task rows without replaying
-- XP: existing level/XP/unlocks stay exactly as stored, and total XP enters
-- the ledger once as a legacy balance. Safe to re-run.
create or replace function public.pt_admin_migrate_legacy(p_slug text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  tid uuid;
  p public.progress;
  k text;
  v_task uuid;
  migrated int := 0;
  unknown text[] := '{}';
begin
  select id into tid from public.trackers where slug = p_slug;
  if tid is null then
    raise exception 'Tracker % not found', p_slug;
  end if;
  if (select data_type from information_schema.columns
      where table_schema = 'public' and table_name = 'progress' and column_name = 'completed_tasks') <> 'ARRAY' then
    raise exception 'progress.completed_tasks is not a text array; convert it before migrating';
  end if;

  for p in select * from public.progress where tracker_id = tid and migrated_at is null for update loop
    foreach k in array coalesce(p.completed_tasks, '{}') loop
      v_task := null;
      select id into v_task from public.tasks where tracker_id = tid and legacy_key = k;
      if v_task is null then
        unknown := array_append(unknown, k);
        continue;
      end if;
      insert into public.task_progress (tracker_id, task_id, user_id, status, completed_at, approved_by, approved_at)
      values (tid, v_task, p.user_id, 'approved', coalesce(p.updated_at, now()), p.user_id, now())
      on conflict (user_id, task_id) do nothing;
    end loop;
    if coalesce(p.total_xp, 0) <> 0 then
      insert into public.xp_events (user_id, tracker_id, amount, reason, note, occurred_on)
      values (p.user_id, tid, p.total_xp, 'legacy_balance', 'Imported total XP', coalesce(p.updated_at, now())::date)
      on conflict (user_id, tracker_id) where reason = 'legacy_balance' do nothing;
    end if;
    update public.progress set migrated_at = now() where id = p.id;
    migrated := migrated + 1;
  end loop;

  return jsonb_build_object('rows_migrated', migrated, 'unknown_task_ids', to_jsonb(unknown));
end $$;

-- =====================================================================
-- Access management (tracker owner, from the Manage page)
-- Levels: none, read (view only), write (complete tasks), review (approve members)
-- =====================================================================
create or replace function public.pt_manage_access(p_tracker uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  tr public.trackers;
begin
  if not public.pt_is_creator(p_tracker) then
    raise exception 'Only the tracker owner can manage access' using errcode = '42501';
  end if;
  select * into tr from public.trackers where id = p_tracker;
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
        'user_id', u.id,
        'name', coalesce(u.display_name, u.email),
        'email', u.email,
        'is_owner', u.id = tr.created_by,
        'level', case
          when a.id is null then 'none'
          when a.role = 'guardian' then 'review'
          when coalesce(a.can_edit, true) then 'write'
          else 'read' end)
      order by (u.id = tr.created_by) desc, coalesce(u.display_name, u.email)), '[]'::jsonb)
    from public.users u
    left join public.tracker_access a on a.tracker_id = p_tracker and a.user_id = u.id);
end $$;

create or replace function public.pt_manage_set_access(p_tracker uuid, p_user uuid, p_level text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  tr public.trackers;
begin
  if not public.pt_is_creator(p_tracker) then
    raise exception 'Only the tracker owner can manage access' using errcode = '42501';
  end if;
  select * into tr from public.trackers where id = p_tracker;
  if p_user = tr.created_by then
    raise exception 'The owner''s access cannot be changed';
  end if;
  if not exists (select 1 from public.users where id = p_user) then
    raise exception 'That person is not approved yet';
  end if;
  if p_level not in ('none', 'read', 'write', 'review') then
    raise exception 'Unknown access level';
  end if;
  if p_level = 'review' and not tr.requires_approval then
    raise exception 'Reviewers are only used on trackers that need approval';
  end if;

  if p_level = 'none' then
    delete from public.tracker_access where tracker_id = p_tracker and user_id = p_user;
  else
    insert into public.tracker_access (tracker_id, user_id, role, can_edit)
    values (p_tracker, p_user, case when p_level = 'review' then 'guardian' else 'member' end, p_level <> 'read')
    on conflict (tracker_id, user_id) do update set role = excluded.role, can_edit = excluded.can_edit;
  end if;
  return jsonb_build_object('level', p_level);
end $$;

-- ---------------------------------------------------------------------
-- Function permissions: only the pt_* functions below are browser-callable
-- ---------------------------------------------------------------------
do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'pt\_%'
  loop
    execute format('revoke all on function %s from public, anon, authenticated', r.sig);
  end loop;
end $$;

grant execute on function public.pt_is_approved() to authenticated;
grant execute on function public.pt_tracker_role(uuid) to authenticated;
grant execute on function public.pt_is_creator(uuid) to authenticated;
grant execute on function public.pt_me() to authenticated;
grant execute on function public.pt_dashboard() to authenticated;
grant execute on function public.pt_complete_task(uuid) to authenticated;
grant execute on function public.pt_uncomplete_task(uuid) to authenticated;
grant execute on function public.pt_review_completion(uuid, boolean) to authenticated;
grant execute on function public.pt_godot_unlock_skill(uuid, text) to authenticated;
grant execute on function public.pt_reset_tracker(uuid) to authenticated;
grant execute on function public.pt_import_completions(uuid, text[]) to authenticated;
grant execute on function public.pt_manage_access(uuid) to authenticated;
grant execute on function public.pt_manage_set_access(uuid, uuid, text) to authenticated;

commit;

-- =====================================================================
-- STEP 2: one-time bootstrap. Back up your data first, then edit the
-- email/IDs below and run the lines you need, one block at a time.
-- =====================================================================
--
-- 1) Approve yourself (sign in on the home page once first):
--    select pt_admin_approve_user('you@example.com', 'Ajay', 'Asia/Kolkata');
--
-- 2) Godot tracker.
--    Already in the database? Find its id: select id, name from trackers;
--    then link it (keeps all existing progress):
--    select pt_admin_link_tracker('<godot-tracker-uuid>', 'godot', 'godot_plan.html', 'godot', 'gamepad');
--    No tracker yet? Create one instead:
--    select pt_admin_create_tracker('godot', 'Godot Game', 'Hack & slash game in Godot 4 with C#',
--      'you@example.com', 'godot', 'godot_plan.html', 'gamepad', false, false);
--
-- 3) 12-week career tracker:
--    select pt_admin_create_tracker('career-pivot', '12-Week Career Pivot', 'Cloud & AI/ML · AI-200 Certification',
--      'you@example.com', 'standard', '3month_plan.html', 'briefcase', false, true);
--
-- 4) Seed tasks (repeatable; never overwrites your edits):
--    select pt_admin_seed('godot');
--    select pt_admin_seed('career-pivot');
--
-- 5) Move old Godot progress into per-task rows (repeatable):
--    select pt_admin_migrate_legacy('godot');
--    Any "unknown_task_ids" are kept in progress.completed_tasks; add matching tasks or ignore them.
--
-- Adding a tracker for a child (they sign in once first):
--    select pt_admin_approve_user('child@example.com', 'Arjun', 'Asia/Kolkata');
--    select pt_admin_create_tracker('arjun-goals', 'Arjun''s Goals', 'Homework, reading and chores',
--      'you@example.com', 'standard', null, 'star', true, true);
--    select pt_admin_grant('arjun-goals', 'child@example.com', 'member');
--    Then add tasks for it on the Manage Tasks page.

-- Competition Periods migration
-- Run this once in the Supabase SQL editor (Dashboard → SQL Editor → New query).

-- 1) Table to track every competition period the camp has ever run.
create table if not exists competition_periods (
  id bigint generated always as identity primary key,
  label text not null,
  start_date date not null,
  end_date date not null,
  is_current boolean not null default false,
  created_at timestamptz not null default now()
);

-- Only one period can be "current" at a time.
create unique index if not exists competition_periods_one_current
  on competition_periods (is_current)
  where is_current;

-- Same open access as the rest of the app's tables (the anon key drives
-- every read/write in this app already — mirroring that here).
alter table competition_periods enable row level security;
drop policy if exists competition_periods_all on competition_periods;
create policy competition_periods_all on competition_periods
  for all using (true) with check (true);

-- 2) Seed the current period from whatever's already in mivtza_config, so
--    the app has something to show immediately (only runs if the table is
--    empty and mivtza_config has dates set).
insert into competition_periods (label, start_date, end_date, is_current)
select 'Current Period', week_start_date, week_end_date, true
from mivtza_config
where week_start_date is not null
  and week_end_date is not null
  and not exists (select 1 from competition_periods)
limit 1;

-- 3) Function to compute weekly points for an arbitrary date range —
--    mirrors the exact scoring formula in camper_profiles.weekly_points
--    (same per-item point values, same hanhaga-item bonus), just
--    parameterized by start/end date instead of reading mivtza_config.
create or replace function camper_points_for_period(p_start date, p_end date)
returns table (
  id uuid,
  name text,
  bunk text,
  class text,
  weekly_points numeric
)
language sql
stable
as $$
  with scored as (
    select de.camper_id,
      de.entry_date,
      (
        (case when de.learn_maamar then 35 else 0 end) +
        (case when de.learn_chumash then 20 else 0 end) +
        (case when de.learn_tanya then 20 else 0 end) +
        (case when de.learn_rambam then 20 else 0 end) +
        (case when de.learn_hayom_yom then 5 else 0 end) +
        (
          (case when de.hanhaga_negel_vasser then 1 else 0 end) +
          (case when de.hanhaga_mikvah then 1 else 0 end) +
          (case when de.hanhaga_brochos then 1 else 0 end) +
          (case when de.hanhaga_tehillim then 1 else 0 end) +
          (case when de.hanhaga_bentching then 1 else 0 end) +
          (case when de.hanhaga_bendel then 1 else 0 end)
        ) * 5
      )::numeric as pts
    from daily_entries de
  )
  select
    c.id,
    c.name,
    c.bunk,
    c.class,
    coalesce(sum(s.pts) filter (where s.entry_date >= p_start and s.entry_date <= p_end), 0::numeric) as weekly_points
  from campers c
  left join scored s on s.camper_id = c.id
  group by c.id, c.name, c.bunk, c.class;
$$;

grant execute on function camper_points_for_period(date, date) to anon, authenticated;

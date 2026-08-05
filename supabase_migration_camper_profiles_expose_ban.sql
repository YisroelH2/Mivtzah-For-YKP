-- Fix: camper_profiles view doesn't expose banned/ban_reason/ban_expires_at.
-- Root cause of "banned camper still shows Active" — the app reads
-- everywhere from camper_profiles, but this view never selected those
-- columns from campers, so bans were invisible to the roster, login
-- screen, and event scanner (banned cards kept working at the door).
--
-- Run this once in the Supabase SQL Editor. It's the existing view
-- definition (from `select pg_get_viewdef('camper_profiles', true)`)
-- with c.banned / c.ban_reason / c.ban_expires_at added to the SELECT
-- and GROUP BY lists — nothing else changed.

create or replace view camper_profiles as
WITH period AS (
         SELECT COALESCE(mivtza_config.week_start_date, date_trunc('week'::text, CURRENT_DATE::timestamp with time zone)::date) AS pstart,
            COALESCE(mivtza_config.week_end_date, (date_trunc('week'::text, CURRENT_DATE::timestamp with time zone) + '6 days'::interval)::date) AS pend
           FROM mivtza_config
          ORDER BY mivtza_config.id
         LIMIT 1
        ), scored AS (
         SELECT de.camper_id,
            de.entry_date,
            (
                CASE
                    WHEN de.learn_maamar THEN 35
                    ELSE 0
                END +
                CASE
                    WHEN de.learn_chumash THEN 20
                    ELSE 0
                END +
                CASE
                    WHEN de.learn_tanya THEN 20
                    ELSE 0
                END +
                CASE
                    WHEN de.learn_rambam THEN 20
                    ELSE 0
                END +
                CASE
                    WHEN de.learn_hayom_yom THEN 5
                    ELSE 0
                END + (
                CASE
                    WHEN de.hanhaga_negel_vasser THEN 1
                    ELSE 0
                END +
                CASE
                    WHEN de.hanhaga_mikvah THEN 1
                    ELSE 0
                END +
                CASE
                    WHEN de.hanhaga_brochos THEN 1
                    ELSE 0
                END +
                CASE
                    WHEN de.hanhaga_tehillim THEN 1
                    ELSE 0
                END +
                CASE
                    WHEN de.hanhaga_bentching THEN 1
                    ELSE 0
                END +
                CASE
                    WHEN de.hanhaga_bendel THEN 1
                    ELSE 0
                END) * 5)::numeric AS pts
           FROM daily_entries de
        )
 SELECT c.id,
    c.name,
    c.nfc_id,
    c.manual_points_adjustment,
    COALESCE(sum(s.pts), 0::numeric) + COALESCE(c.manual_points_adjustment, 0)::numeric AS total_points,
    COALESCE(sum(s.pts) FILTER (WHERE s.entry_date >= (( SELECT period.pstart
           FROM period)) AND s.entry_date <= (( SELECT period.pend
           FROM period))), 0::numeric) AS weekly_points,
        CASE
            WHEN (COALESCE(sum(s.pts), 0::numeric) + COALESCE(c.manual_points_adjustment, 0)::numeric) >= 3600::numeric THEN 'Black'::text
            WHEN (COALESCE(sum(s.pts), 0::numeric) + COALESCE(c.manual_points_adjustment, 0)::numeric) >= 1800::numeric THEN 'Platinum'::text
            ELSE 'Gold'::text
        END AS card_status,
        CASE
            WHEN COALESCE(sum(s.pts) FILTER (WHERE s.entry_date >= (( SELECT period.pstart
               FROM period)) AND s.entry_date <= (( SELECT period.pend
               FROM period))), 0::numeric) >= 700::numeric THEN 'VIP'::text
            WHEN COALESCE(sum(s.pts) FILTER (WHERE s.entry_date >= (( SELECT period.pstart
               FROM period)) AND s.entry_date <= (( SELECT period.pend
               FROM period))), 0::numeric) >= 400::numeric THEN 'Standard'::text
            ELSE 'Not Eligible'::text
        END AS weekly_event_status,
    c.bunk,
    c.class,
    c.banned,
    c.ban_reason,
    c.ban_expires_at
   FROM campers c
     LEFT JOIN scored s ON s.camper_id = c.id
  GROUP BY c.id, c.name, c.nfc_id, c.manual_points_adjustment, c.bunk, c.class, c.banned, c.ban_reason, c.ban_expires_at;

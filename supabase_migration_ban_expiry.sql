-- Ban auto-expiry migration
-- Run this once in the Supabase SQL editor (Dashboard → SQL Editor → New query).
-- Requires supabase_migration_ban.sql to have already been run.
--
-- Adds an optional expiry timestamp to a ban. NULL means the ban is
-- indefinite (until an admin manually unbans). When set, the app treats the
-- ban as over once this time passes — LoginScreen and the roster both
-- self-heal by clearing `banned`/`ban_reason`/`ban_expires_at` the next
-- time they read a camper whose ban has expired (there's no server-side
-- cron in this app, so expiry is checked lazily on read instead).

alter table campers add column if not exists ban_expires_at timestamptz;

-- If camper_profiles is a view with an explicit column list (rather than
-- `select c.*`), add `c.ban_expires_at` to it the same way described in
-- supabase_migration_ban.sql for the `banned`/`ban_reason` columns.

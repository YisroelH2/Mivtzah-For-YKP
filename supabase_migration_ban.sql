-- Ban a camper migration
-- Run this once in the Supabase SQL editor (Dashboard → SQL Editor → New query).
--
-- Adds a `banned` flag (+ optional reason) to campers. A banned camper's
-- data is untouched — their card just stops working: LoginScreen shows a
-- "You have been banned" screen instead of logging them in, and the Event
-- Scanner shows a banned/denied screen at the door instead of admitting them.

alter table campers add column if not exists banned boolean not null default false;
alter table campers add column if not exists ban_reason text;

-- camper_profiles is a VIEW over campers (see the comment above
-- CAMPER_READ_TABLE in index.html) that the app reads from everywhere.
-- If it was created as `select c.*, <computed columns> from campers c ...`
-- then `banned`/`ban_reason` are already exposed automatically and there's
-- nothing else to do. If instead it lists columns explicitly, add
-- `c.banned` and `c.ban_reason` to that view's select list and re-run
-- `create or replace view camper_profiles as ...` with the rest of its
-- existing definition unchanged.
--
-- To check which case you're in, run:
--   select banned from camper_profiles limit 1;
-- If that errors with "column does not exist", the view needs the update
-- described above.

-- 01_schema_cleanup.sql
-- Purpose: Normalize GA export tables in SQLite (DBeaver) to clean snake_case schema.
-- How to use:
-- 1) Import your CSVs as tables (raw names). Common raw names:
--      01_traffic_source_medium
--      02_events
--      03_events_by_source   (or 03_events_by_source_clean)
-- 2) Run this script ONCE (as a script: Alt+X in DBeaver). After renames, running again will fail
--    because old column names no longer exist.

PRAGMA foreign_keys = OFF;

-- =========================
-- A) RENAME TABLES
-- =========================
-- If your raw tables already have the target names, comment these out.

ALTER TABLE "01_traffic_source_medium" RENAME TO traffic_source_medium;
ALTER TABLE "02_events" RENAME TO events;

-- If your third table is named differently, use the correct line and comment the other.
-- ALTER TABLE "03_events_by_source" RENAME TO events_by_source;
ALTER TABLE "03_events_by_source_clean" RENAME TO events_by_source;

-- =========================
-- B) RENAME COLUMNS to snake_case
-- =========================

-- traffic_source_medium
ALTER TABLE traffic_source_medium RENAME COLUMN "Session source/medium" TO session_source_medium;
ALTER TABLE traffic_source_medium RENAME COLUMN "Sessions" TO sessions;
ALTER TABLE traffic_source_medium RENAME COLUMN "Engaged sessions" TO engaged_sessions;
ALTER TABLE traffic_source_medium RENAME COLUMN "Engagement rate" TO engagement_rate;
ALTER TABLE traffic_source_medium RENAME COLUMN "Average engagement time per session" TO avg_engagement_time_per_session;
ALTER TABLE traffic_source_medium RENAME COLUMN "Events per session" TO events_per_session;
ALTER TABLE traffic_source_medium RENAME COLUMN "Event count" TO event_count;
ALTER TABLE traffic_source_medium RENAME COLUMN "Key events" TO key_events;
ALTER TABLE traffic_source_medium RENAME COLUMN "Session key event rate" TO session_key_event_rate;
ALTER TABLE traffic_source_medium RENAME COLUMN "Total revenue" TO total_revenue;

-- events
ALTER TABLE events RENAME COLUMN "Event name" TO event_name;
ALTER TABLE events RENAME COLUMN "Event count" TO event_count;
ALTER TABLE events RENAME COLUMN "Total users" TO total_users;
ALTER TABLE events RENAME COLUMN "Event count per active user" TO event_count_per_active_user;
ALTER TABLE events RENAME COLUMN "Total revenue" TO total_revenue;

-- events_by_source
ALTER TABLE events_by_source RENAME COLUMN "Event name" TO event_name;
ALTER TABLE events_by_source RENAME COLUMN "Session source/medium" TO session_source_medium;
ALTER TABLE events_by_source RENAME COLUMN "Event count" TO event_count;

-- =========================
-- C) DATA CLEANING (events_by_source)
-- =========================
-- Remove header row accidentally imported as data + empty rows
DELETE FROM events_by_source
WHERE event_name IS NULL
   OR session_source_medium IS NULL
   OR event_count IS NULL
   OR event_name = 'Event name'
   OR session_source_medium = 'Session source/medium';

-- =========================
-- D) QUICK CHECKS
-- =========================
SELECT name, type
FROM sqlite_master
WHERE type IN ('table','view')
ORDER BY type, name;

PRAGMA table_info(traffic_source_medium);
PRAGMA table_info(events);
PRAGMA table_info(events_by_source);

PRAGMA foreign_keys = ON;

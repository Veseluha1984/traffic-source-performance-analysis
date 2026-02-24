-- 02_analysis.sql
-- Purpose: BI analysis queries for portfolio project (SQLite).
-- Assumes schema has been cleaned with 01_schema_cleanup.sql:
--   traffic_source_medium(session_source_medium, sessions, engaged_sessions, engagement_rate, ...)
--   events(event_name, event_count, total_users, ...)
--   events_by_source(event_name, session_source_medium, event_count)

-- =========================
-- 1) Total events by source
-- =========================
SELECT
  session_source_medium AS source,
  SUM(event_count) AS total_events
FROM events_by_source
GROUP BY session_source_medium
ORDER BY total_events DESC;

-- =========================
-- 2) Top event per source (ties allowed)
-- =========================
SELECT *
FROM (
    SELECT
        session_source_medium AS source,
        event_name,
        event_count,
        RANK() OVER (
            PARTITION BY session_source_medium
            ORDER BY event_count DESC
        ) AS rnk
    FROM events_by_source
)
WHERE rnk = 1
ORDER BY source;

-- =========================
-- 3) Exactly one top row per source (tie-breaker)
-- =========================
SELECT *
FROM (
    SELECT
        session_source_medium AS source,
        event_name,
        event_count,
        ROW_NUMBER() OVER (
            PARTITION BY session_source_medium
            ORDER BY event_count DESC, event_name ASC
        ) AS rn
    FROM events_by_source
)
WHERE rn = 1
ORDER BY source;

-- =========================
-- 4) Event share within each source (CTE)
-- =========================
WITH totals AS (
    SELECT
        session_source_medium AS source,
        SUM(event_count) AS total_events
    FROM events_by_source
    GROUP BY session_source_medium
)
SELECT
    e.session_source_medium AS source,
    e.event_name,
    e.event_count,
    ROUND(100.0 * e.event_count / t.total_events, 2) AS event_share_pct
FROM events_by_source e
JOIN totals t
  ON t.source = e.session_source_medium
ORDER BY source, event_share_pct DESC;

-- =========================
-- 5) Channel metrics (GA acquisition table)
-- =========================
SELECT
  session_source_medium AS source,
  sessions,
  engaged_sessions,
  engagement_rate,
  events_per_session,
  key_events,
  session_key_event_rate
FROM traffic_source_medium
ORDER BY engagement_rate DESC;

-- =========================
-- 6) Key events per session + weighted score (simple KPI model)
-- =========================
SELECT
  session_source_medium AS source,
  sessions,
  engagement_rate,
  events_per_session,
  key_events,
  ROUND(1.0 * key_events / NULLIF(sessions, 0), 4) AS key_events_per_session,
  ROUND(
      engagement_rate * 0.4 +
      events_per_session * 0.3 +
      (1.0 * key_events / NULLIF(sessions, 0)) * 0.3
  , 4) AS weighted_score
FROM traffic_source_medium
ORDER BY weighted_score DESC;

-- =========================
-- 7) Conversion rate: cv_downloads per session
-- =========================
WITH cv AS (
    SELECT
        session_source_medium AS source,
        SUM(event_count) AS cv_downloads
    FROM events_by_source
    WHERE event_name = 'cv_download'
    GROUP BY session_source_medium
)
SELECT
    t.session_source_medium AS source,
    t.sessions,
    t.engagement_rate,
    t.events_per_session,
    COALESCE(c.cv_downloads, 0) AS cv_downloads,
    ROUND(1.0 * COALESCE(c.cv_downloads, 0) / NULLIF(t.sessions, 0), 4) AS cv_rate
FROM traffic_source_medium t
LEFT JOIN cv c
  ON t.session_source_medium = c.source
ORDER BY cv_rate DESC, t.sessions DESC;

-- =========================
-- 8) Market share of events by source
-- =========================
WITH total AS (
    SELECT SUM(event_count) AS grand_total
    FROM events_by_source
)
SELECT
    session_source_medium,
    SUM(event_count) AS source_events,
    ROUND(100.0 * SUM(event_count) / total.grand_total, 2) AS share_pct
FROM events_by_source, total
GROUP BY session_source_medium
ORDER BY share_pct DESC;

-- =========================
-- 9) Min-max normalization
-- =========================
WITH base AS (
    SELECT
        t.session_source_medium AS source,
        t.sessions,
        t.engagement_rate,
        t.events_per_session,
        ROUND(1.0 * COALESCE(c.cv_downloads, 0) / NULLIF(t.sessions, 0), 4) AS cv_rate
    FROM traffic_source_medium t
    LEFT JOIN (
        SELECT session_source_medium, SUM(event_count) AS cv_downloads
        FROM events_by_source
        WHERE event_name = 'cv_download'
        GROUP BY session_source_medium
    ) c
    ON t.session_source_medium = c.session_source_medium
),
stats AS (
    SELECT
        MIN(sessions) AS min_sessions, MAX(sessions) AS max_sessions,
        MIN(engagement_rate) AS min_eng, MAX(engagement_rate) AS max_eng,
        MIN(events_per_session) AS min_eps, MAX(events_per_session) AS max_eps,
        MIN(cv_rate) AS min_cv, MAX(cv_rate) AS max_cv
    FROM base
)
SELECT
    b.source,
    b.sessions,
    b.engagement_rate,
    b.events_per_session,
    b.cv_rate,
    ROUND((b.sessions - s.min_sessions) / NULLIF(s.max_sessions - s.min_sessions,0), 4) AS norm_sessions,
    ROUND((b.engagement_rate - s.min_eng) / NULLIF(s.max_eng - s.min_eng,0), 4) AS norm_engagement,
    ROUND((b.events_per_session - s.min_eps) / NULLIF(s.max_eps - s.min_eps,0), 4) AS norm_eps,
    ROUND((b.cv_rate - s.min_cv) / NULLIF(s.max_cv - s.min_cv,0), 4) AS norm_cv
FROM base b
CROSS JOIN stats s;

-- =========================
-- 10) Channel Performance Index (CPI)
-- =========================
WITH base AS (
    SELECT
        t.session_source_medium AS source,
        t.sessions,
        t.engagement_rate,
        t.events_per_session,
        ROUND(1.0 * COALESCE(c.cv_downloads, 0) / NULLIF(t.sessions, 0), 4) AS cv_rate
    FROM traffic_source_medium t
    LEFT JOIN (
        SELECT session_source_medium, SUM(event_count) AS cv_downloads
        FROM events_by_source
        WHERE event_name = 'cv_download'
        GROUP BY session_source_medium
    ) c
    ON t.session_source_medium = c.session_source_medium
),
stats AS (
    SELECT
        MIN(sessions) AS min_sessions, MAX(sessions) AS max_sessions,
        MIN(engagement_rate) AS min_eng, MAX(engagement_rate) AS max_eng,
        MIN(events_per_session) AS min_eps, MAX(events_per_session) AS max_eps,
        MIN(cv_rate) AS min_cv, MAX(cv_rate) AS max_cv
    FROM base
)
SELECT
    b.source,
    ROUND(
        0.30 * ((b.sessions - s.min_sessions) / NULLIF(s.max_sessions - s.min_sessions,0)) +
        0.25 * ((b.engagement_rate - s.min_eng) / NULLIF(s.max_eng - s.min_eng,0)) +
        0.25 * ((b.events_per_session - s.min_eps) / NULLIF(s.max_eps - s.min_eps,0)) +
        0.20 * ((b.cv_rate - s.min_cv) / NULLIF(s.max_cv - s.min_cv,0))
    , 4) AS channel_performance_index
FROM base b
CROSS JOIN stats s
ORDER BY channel_performance_index DESC;

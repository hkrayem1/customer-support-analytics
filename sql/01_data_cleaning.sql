USE CustomerSupportAnalytics;
GO

-- ============================================
-- CUSTOMER SUPPORT ANALYTICS
-- 01 - DATA CLEANING & VALIDATION
-- ============================================

-- 1. Check total ticket count
SELECT COUNT(*) AS total_tickets
FROM dbo.tickets;


-- 2. Identify duplicate ticket IDs
SELECT
    ticket_id,
    COUNT(*) AS duplicate_count
FROM dbo.tickets
GROUP BY ticket_id
HAVING COUNT(*) > 1;


-- 3. Demonstrate duplicate detection using ROW_NUMBER()
-- Read-only: no records are deleted

WITH DuplicateCheck AS (
    SELECT
        ticket_id,
        ROW_NUMBER() OVER (
            PARTITION BY ticket_id
            ORDER BY ticket_id
        ) AS row_num
    FROM dbo.tickets
)
SELECT *
FROM DuplicateCheck
WHERE row_num > 1;


-- 4. Check missing agent assignments
SELECT
    COUNT(*) AS unassigned_tickets
FROM dbo.tickets
WHERE agent_id IS NULL;


-- 5. Check unresolved tickets
SELECT
    status,
    COUNT(*) AS ticket_count
FROM dbo.tickets
WHERE resolved_at IS NULL
GROUP BY status;


-- 6. Check missing CSAT scores
SELECT
    COUNT(*) AS missing_csat_scores
FROM dbo.satisfaction
WHERE csat_score IS NULL;


-- 7. Check for invalid timestamps
SELECT COUNT(*) AS invalid_timestamps
FROM dbo.tickets
WHERE
    first_response_at < created_at
    OR resolved_at < created_at
    OR resolved_at < first_response_at;

-- 8. Investigate invalid timestamp sequences
SELECT
    SUM(CASE
        WHEN first_response_at < created_at
        THEN 1 ELSE 0
    END) AS response_before_creation,

    SUM(CASE
        WHEN resolved_at < created_at
        THEN 1 ELSE 0
    END) AS resolution_before_creation,

    SUM(CASE
        WHEN resolved_at < first_response_at
        THEN 1 ELSE 0
    END) AS resolution_before_response

FROM dbo.tickets;


-- 9. Investigate tickets resolved before first response

SELECT TOP 20
    ticket_id,
    status,
    created_at,
    first_response_at,
    resolved_at,
    DATEDIFF(MINUTE, created_at, resolved_at) / 60.0
        AS resolution_hours,
    DATEDIFF(MINUTE, created_at, first_response_at) / 60.0
        AS response_hours
FROM dbo.tickets
WHERE resolved_at < first_response_at
ORDER BY ticket_id;


-- ============================================
-- DATA QUALITY FINDING
-- ============================================

-- 1,741 tickets (3.32%) have a resolution timestamp
-- earlier than their first-response timestamp.
--
-- These records have been retained because the
-- original timestamps cannot be reliably corrected.
--
-- Impact:
-- SLA calculations remain mathematically valid
-- relative to ticket creation, but the affected
-- records contain an inconsistent event sequence.
--
-- Recommendation:
-- Enforce created_at <= first_response_at <= resolved_at
-- for standard resolved-ticket workflows during
-- future data generation or ingestion.
--
-- No records were modified during this investigation.
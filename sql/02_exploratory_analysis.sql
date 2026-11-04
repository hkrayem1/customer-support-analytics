
USE CustomerSupportAnalytics;
GO

-- ================================================
-- CUSTOMER SUPPORT ANALYTICS
-- 02 - EXPLORATORY DATA ANALYSIS
-- ================================================
-- Dataset: January 2025 - June 2026
-- All queries are read-only.
-- ================================================


-- 1. OVERALL SUPPORT PERFORMANCE
-- Establish baseline KPIs for the dashboard.

SELECT
    COUNT(*) AS total_tickets,

    SUM(CASE
        WHEN response_sla_status = 'MET SLA'
        THEN 1 ELSE 0
    END) AS response_sla_met,

    ROUND(
        100.0 * SUM(CASE
            WHEN response_sla_status = 'MET SLA'
            THEN 1 ELSE 0
        END) / NULLIF(COUNT(*), 0),
        2
    ) AS response_sla_pct,

    ROUND(
        100.0 * SUM(CASE
            WHEN resolution_sla_status = 'MET SLA'
            THEN 1 ELSE 0
        END)
        / NULLIF(SUM(CASE
            WHEN resolution_sla_status IN ('MET SLA', 'BREACHED SLA')
            THEN 1 ELSE 0
        END), 0),
        2
    ) AS resolution_sla_pct,

    SUM(CASE
        WHEN resolved_at IS NULL
        THEN 1 ELSE 0
    END) AS unresolved_tickets,

    ROUND(AVG(csat_score), 2) AS average_csat

FROM dbo.vw_ticket_analysis;


-- 2. RESPONSE SLA PERFORMANCE BY CATEGORY
-- Identify categories with low SLA compliance
-- and high breach volumes.

SELECT
    category,
    COUNT(*) AS total_tickets,

    SUM(CASE
        WHEN response_sla_status = 'BREACHED SLA'
        THEN 1 ELSE 0
    END) AS response_breaches,

    ROUND(
        100.0 * SUM(CASE
            WHEN response_sla_status = 'MET SLA'
            THEN 1 ELSE 0
        END) / NULLIF(COUNT(*), 0),
        2
    ) AS response_sla_pct

FROM dbo.vw_ticket_analysis
GROUP BY category
ORDER BY response_sla_pct ASC;


-- 3. RESPONSE VS RESOLUTION SLA BY CATEGORY
-- Compare acknowledgement and resolution performance.

SELECT
    category,

    ROUND(
        100.0 * SUM(CASE
            WHEN response_sla_status = 'MET SLA'
            THEN 1 ELSE 0
        END) / NULLIF(COUNT(*), 0),
        2
    ) AS response_sla_pct,

    ROUND(
        100.0 * SUM(CASE
            WHEN resolution_sla_status = 'MET SLA'
            THEN 1 ELSE 0
        END)
        / NULLIF(SUM(CASE
            WHEN resolution_sla_status IN ('MET SLA', 'BREACHED SLA')
            THEN 1 ELSE 0
        END), 0),
        2
    ) AS resolution_sla_pct

FROM dbo.vw_ticket_analysis
GROUP BY category
ORDER BY response_sla_pct ASC;


-- 4. SUPPORT TEAM PERFORMANCE
-- Compare workload, SLA compliance and CSAT.

SELECT
    COALESCE(team, 'Unassigned') AS support_team,
    COUNT(*) AS total_tickets,

    SUM(CASE
        WHEN response_sla_status = 'BREACHED SLA'
        THEN 1 ELSE 0
    END) AS response_breaches,

    ROUND(
        100.0 * SUM(CASE
            WHEN response_sla_status = 'MET SLA'
            THEN 1 ELSE 0
        END) / NULLIF(COUNT(*), 0),
        2
    ) AS response_sla_pct,

    ROUND(AVG(csat_score), 2) AS average_csat

FROM dbo.vw_ticket_analysis
GROUP BY COALESCE(team, 'Unassigned')
ORDER BY response_sla_pct ASC;


-- 5. TEAM PERFORMANCE BY TICKET CATEGORY
-- Explore whether SLA performance varies
-- between teams handling the same categories.

SELECT
    COALESCE(team, 'Unassigned') AS support_team,
    category,
    COUNT(*) AS total_tickets,

    ROUND(
        100.0 * SUM(CASE
            WHEN response_sla_status = 'MET SLA'
            THEN 1 ELSE 0
        END) / NULLIF(COUNT(*), 0),
        2
    ) AS response_sla_pct

FROM dbo.vw_ticket_analysis
GROUP BY COALESCE(team, 'Unassigned'), category
ORDER BY category, response_sla_pct ASC;


-- 6. MONTHLY TICKET VOLUME AND SLA PERFORMANCE
-- Investigate trends and performance changes
-- between January 2025 and June 2026.

WITH MonthlyPerformance AS (
    SELECT
        DATEFROMPARTS(
            YEAR(created_at),
            MONTH(created_at),
            1
        ) AS ticket_month,

        COUNT(*) AS total_tickets,

        SUM(CASE
            WHEN response_sla_status = 'MET SLA'
            THEN 1 ELSE 0
        END) AS response_sla_met

    FROM dbo.vw_ticket_analysis
    GROUP BY
        YEAR(created_at),
        MONTH(created_at)
)

SELECT
    ticket_month,
    total_tickets,

    ROUND(
        100.0 * response_sla_met
        / NULLIF(total_tickets, 0),
        2
    ) AS response_sla_pct

FROM MonthlyPerformance
ORDER BY ticket_month;


-- 7. MONTHLY RESPONSE SLA BY TEAM
-- Determine whether changes affected
-- individual teams or the wider operation.

SELECT
    DATEFROMPARTS(
        YEAR(created_at),
        MONTH(created_at),
        1
    ) AS ticket_month,

    COALESCE(team, 'Unassigned') AS support_team,
    COUNT(*) AS total_tickets,

    ROUND(
        100.0 * SUM(CASE
            WHEN response_sla_status = 'MET SLA'
            THEN 1 ELSE 0
        END) / NULLIF(COUNT(*), 0),
        2
    ) AS response_sla_pct

FROM dbo.vw_ticket_analysis
GROUP BY
    YEAR(created_at),
    MONTH(created_at),
    COALESCE(team, 'Unassigned')
ORDER BY ticket_month, support_team;


-- 8. CUSTOMER SATISFACTION VS RESPONSE SLA
-- Assess the association between response
-- SLA compliance and customer satisfaction.

SELECT
    response_sla_status,
    COUNT(csat_score) AS rated_tickets,
    ROUND(AVG(csat_score), 2) AS average_csat

FROM dbo.vw_ticket_analysis
WHERE csat_score IS NOT NULL
GROUP BY response_sla_status
ORDER BY average_csat DESC;


-- 9. CUSTOMER SATISFACTION VS RESOLUTION SLA
-- Compare satisfaction between tickets
-- that met and breached resolution targets.

SELECT
    resolution_sla_status,
    COUNT(csat_score) AS rated_tickets,
    ROUND(AVG(csat_score), 2) AS average_csat

FROM dbo.vw_ticket_analysis
WHERE csat_score IS NOT NULL
GROUP BY resolution_sla_status
ORDER BY average_csat DESC;


-- 10. CSAT COVERAGE AMONG RESOLVED TICKETS
-- Measure the proportion of resolved tickets
-- with a recorded customer satisfaction score.

SELECT
    SUM(CASE
        WHEN resolved_at IS NOT NULL
        THEN 1 ELSE 0
    END) AS resolved_tickets,

    SUM(CASE
        WHEN resolved_at IS NOT NULL
             AND csat_score IS NOT NULL
        THEN 1 ELSE 0
    END) AS rated_tickets,

    ROUND(
        100.0 * SUM(CASE
            WHEN resolved_at IS NOT NULL
                 AND csat_score IS NOT NULL
            THEN 1 ELSE 0
        END)
        / NULLIF(SUM(CASE
            WHEN resolved_at IS NOT NULL
            THEN 1 ELSE 0
        END), 0),
        2
    ) AS csat_coverage_pct

FROM dbo.vw_ticket_analysis;

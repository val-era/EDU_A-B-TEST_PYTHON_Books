-- ==============================================================================
-- АНАЛИТИЧЕСКИЕ SQL‑ЗАПРОСЫ ДЛЯ ПРОЕКТА BOOKMATE
-- Автор: Игнатьев Валерий
-- Дата: 2025-11-30
-- СУБД: PostgreSQL
-- ==============================================================================

/*
-------------------------------------------------------------------------------
1. РАСЧЁТ MAU АВТОРОВ (ТОП‑3 В НОЯБРЕ 2024)
Цель: выявить топ‑3 авторов по количеству активных пользователей (MAU) в ноябре 2024 г.
-------------------------------------------------------------------------------
*/
SELECT
    main_author_name,
    COUNT(DISTINCT puid) AS MAU
FROM bookmate.audition AS ba
LEFT JOIN bookmate.content AS bc ON ba.main_content_id = bc.main_content_id
LEFT JOIN bookmate.author AS bau ON bc.main_author_id = bau.main_author_id
WHERE msk_business_dt_str BETWEEN '2024-11-01' AND '2024-11-30'
GROUP BY main_author_name
ORDER BY MAU DESC
LIMIT 3;



/*
-------------------------------------------------------------------------------
2. РАСЧЁТ MAU ПРОИЗВЕДЕНИЙ (ТОП‑3 В НОЯБРЕ 2024)
Цель: найти топ‑3 произведения по MAU, включая их жанры и авторов.
-------------------------------------------------------------------------------
*/
SELECT
    main_content_name,
    published_topic_title_list,
    main_author_name,
    COUNT(DISTINCT puid) AS mau
FROM bookmate.audition AS ba
LEFT JOIN bookmate.content AS bc ON ba.main_content_id = bc.main_content_id
LEFT JOIN bookmate.author AS bau ON bc.main_author_id = bau.main_author_id
WHERE msk_business_dt_str BETWEEN '2024-11-01' AND '2024-11-30'
GROUP BY main_content_name, published_topic_title_list, main_author_name
ORDER BY mau DESC
LIMIT 3;



/*
-------------------------------------------------------------------------------
3. РАСЧЁТ RETENTION RATE (ЕЖЕДНЕВНЫЙ)
Цель: рассчитать ежедневный коэффициент удержания пользователей с 2 декабря 2024 г.
-------------------------------------------------------------------------------
*/
WITH active_users AS (
    SELECT DISTINCT puid
    FROM bookmate.audition
    WHERE msk_business_dt_str = '2024-12-02'
),
day_after_install AS (
    SELECT
        msk_business_dt_str,
        COUNT(DISTINCT puid) AS retained_users
    FROM bookmate.audition
    WHERE puid IN (SELECT puid FROM active_users)
      AND msk_business_dt_str > '2024-12-01'
    GROUP BY msk_business_dt_str
)
SELECT
    (msk_business_dt_str::date - '2024-12-02'::date) AS day_since_install,
    retained_users,
    ROUND(retained_users::NUMERIC / MAX(retained_users) OVER (), 2) AS retention_rate
FROM day_after_install
ORDER BY day_since_install;




/*
-------------------------------------------------------------------------------
4. РАСЧЁТ LTV ПО ГОРОДАМ (МОСКВА И САНКТ‑ПЕТЕРБУРГ)
Цель: сравнить средний Lifetime Value (LTV) пользователей в Москве и СПб.
-------------------------------------------------------------------------------
*/
WITH users_by_month AS (
    SELECT
        usage_geo_id,
        puid,
        COUNT(DISTINCT EXTRACT(MONTH FROM msk_business_dt_str)) * 399 AS ltv
    FROM bookmate.audition
    GROUP BY usage_geo_id, puid
)
SELECT
    usage_geo_id_name AS city,
    COUNT(DISTINCT puid) AS total_users,
    ROUND(AVG(ltv), 2) AS ltv
FROM users_by_month AS ubm
LEFT JOIN bookmate.geo AS bg ON ubm.usage_geo_id = bg.usage_geo_id
WHERE usage_geo_id_name IN ('Москва', 'Санкт-Петербург')
GROUP BY usage_geo_id_name;




/*
-------------------------------------------------------------------------------
5. РАСЧЁТ СРЕДНЕЙ ВЫРУЧКИ НА ПРОСЛУШАННЫЙ ЧАС (АНАЛОГ СРЕДНЕГО ЧЕКА)
Цель: рассчитать выручку на час прослушивания вместе с MAU и общим временем.
Период: сентябрь–ноябрь 2024 г.
-------------------------------------------------------------------------------
*/
SELECT
    DATE_TRUNC('month', msk_business_dt_str)::DATE AS month,
    COUNT(DISTINCT puid) AS mau,
    ROUND(SUM(hours), 2) AS hours,
    ROUND((COUNT(DISTINCT puid) * 399) / SUM(hours), 2) AS avg_hour_rev
FROM bookmate.audition
WHERE msk_business_dt_str BETWEEN '2024-09-01' AND '2024-11-30'
GROUP BY DATE_TRUNC('month', msk_business_dt_str)::DATE
ORDER BY month;

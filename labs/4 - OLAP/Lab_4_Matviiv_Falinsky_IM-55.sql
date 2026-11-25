-- ЛАБОРАТОРНА РОБОТА №4. Аналітичні SQL-запити (OLAP)
-- Схема та тестові дані з лабораторної №2 (перед запуском виконати скрипт ЛР №2).


-- ===================== 1. АГРЕГАЦІЯ, GROUP BY ТА HAVING =====================

-- 1.1 Базова агрегація по одній таблиці (Player_Inventory):
-- COUNT(*) vs COUNT(item_level) (ігнорує NULL) vs COUNT(DISTINCT player_id), SUM, AVG, MIN, MAX
SELECT COUNT(*)                  AS total_inventory_rows,
       COUNT(item_level)         AS leveled_items_count,
       COUNT(DISTINCT player_id) AS players_with_items,
       SUM(quantity)             AS total_item_quantity,
       ROUND(AVG(item_level), 2) AS avg_item_level,
       MIN(item_level)           AS min_item_level,
       MAX(item_level)           AS max_item_level
FROM Player_Inventory;

-- 1.2 Групування даних (GROUP BY): зведена статистика матчів за результатом
SELECT result,
       COUNT(*)             AS participations_count,
       SUM(kills)           AS total_kills,
       SUM(deaths)          AS total_deaths,
       ROUND(AVG(score), 2) AS avg_score,
       MAX(score)           AS max_score
FROM Match_Player
GROUP BY result
ORDER BY avg_score DESC;

-- 1.3 Фільтрування згрупованих даних (GROUP BY + HAVING):
-- регіони серверів із сумарною місткістю понад 15000 гравців
SELECT region,
       COUNT(*)                    AS servers_count,
       SUM(max_capacity)           AS total_capacity,
       ROUND(AVG(max_capacity), 2) AS avg_capacity
FROM Server
GROUP BY region
HAVING SUM(max_capacity) > 15000
ORDER BY total_capacity DESC;

-- 1.4 Багатотаблична агрегація (LEFT JOIN + GROUP BY + COALESCE):
-- активність і сумарні очки гравців по кожному домашньому серверу (включно з порожніми серверами)
SELECT s.name                                AS server_name,
       COUNT(DISTINCT p.player_id)           AS players_count,
       COUNT(mp.match_id)                    AS match_participations,
       COALESCE(SUM(mp.score), 0)            AS total_score,
       COALESCE(SUM(mp.resources_earned), 0) AS total_resources_earned
FROM Server s
LEFT JOIN Player p USING (server_id)
LEFT JOIN Match_Player mp USING (player_id)
GROUP BY s.server_id
ORDER BY total_score DESC, server_name;


-- ===================== 2. РІЗНІ ТИПИ JOIN =====================

-- 2.1 INNER JOIN (4 таблиці): детальна статистика участі гравців у матчах із сервером проведення
SELECT m.match_id,
       s.name      AS match_server,
       p.nickname,
       mp.result,
       mp.score,
       mp.kills,
       mp.deaths
FROM Match_Player mp
INNER JOIN Player p ON mp.player_id = p.player_id
INNER JOIN Match m  ON mp.match_id  = m.match_id
INNER JOIN Server s ON m.server_id  = s.server_id
ORDER BY m.match_id, mp.score DESC;

-- 2.2 LEFT JOIN (3 таблиці): усі гравці та їхній інвентар (включно з гравцями без предметів)
SELECT p.nickname,
       i.name       AS item_name,
       i.category,
       pi.quantity,
       pi.item_level
FROM Player p
LEFT JOIN Player_Inventory pi ON p.player_id = pi.player_id
LEFT JOIN Item i              ON pi.item_id  = i.item_id
ORDER BY p.nickname, i.name;

-- 2.3 CROSS JOIN + anti-join (LEFT JOIN ... WHERE ... IS NULL):
-- які предмети з каталогу ще відсутні в інвентарі кожного гравця
SELECT p.nickname,
       i.name     AS missing_item,
       i.category
FROM Player p
CROSS JOIN Item i
LEFT JOIN Player_Inventory pi
       ON pi.player_id = p.player_id
      AND pi.item_id   = i.item_id
WHERE pi.item_id IS NULL
ORDER BY p.nickname, i.category, i.name;


-- ===================== 3. ПІДЗАПИТИ (SELECT, WHERE, HAVING) =====================

-- 3.1 Підзапит у SELECT (скалярний некорельований):
-- рейтинг кожного гравця поруч із середнім рейтингом по платформі
SELECT p.nickname,
       p.rating,
       (SELECT ROUND(AVG(rating), 2) FROM Player) AS platform_avg_rating
FROM Player p
ORDER BY p.rating DESC;

-- 3.2 Підзапит у WHERE (скалярний некорельований):
-- гравці з рейтингом вище середнього по платформі
SELECT p.nickname,
       p.level,
       p.rating
FROM Player p
WHERE p.rating > (
    SELECT AVG(rating)
    FROM Player
)
ORDER BY p.rating DESC;

-- 3.3 Підзапит у WHERE з NOT EXISTS (корельований, безпечний для NULL):
-- сервери, на яких ще не було проведено жодного матчу
SELECT s.server_id,
       s.name,
       s.region,
       s.max_capacity
FROM Server s
WHERE NOT EXISTS (
    SELECT 1
    FROM Match m
    WHERE m.server_id = s.server_id
)
ORDER BY s.server_id;

-- 3.4 Підзапит у HAVING (скалярний некорельований):
-- сервери, де середній рейтинг гравців перевищує середній рейтинг по всій платформі
SELECT s.name                  AS server_name,
       COUNT(p.player_id)      AS players_count,
       ROUND(AVG(p.rating), 2) AS server_avg_rating
FROM Server s
INNER JOIN Player p USING (server_id)
GROUP BY s.server_id
HAVING AVG(p.rating) > (
    SELECT AVG(rating)
    FROM Player
)
ORDER BY server_avg_rating DESC;
-- 25日平均ルールで「予測 → 答え合わせ」を過去の日足でまとめて行う（#38）
-- ルール：基準日の終値が、その日を含む直近25取引日の終値平均より上なら「h 取引日後は上がる」と予測する
-- 基準：毎日「上がる」と言う
-- 出すのは件数・率・日付だけ（株価の値は出さない＝J-Quants の規約）
SET NOCOUNT ON;
DECLARE @code VARCHAR(5) = '25590';

WITH base AS (
    SELECT
        trade_date,
        close_price,
        AVG(close_price) OVER (ORDER BY trade_date ROWS BETWEEN 24 PRECEDING AND CURRENT ROW) AS ma25,
        -- 先頭の24日は平均に使う行が25に満たない＝対象から外すために数えておく
        COUNT(*)         OVER (ORDER BY trade_date ROWS BETWEEN 24 PRECEDING AND CURRENT ROW) AS ma_rows,
        -- 取引日の数え方＝prices に入っている行の順（休場日は行が無いので自然に飛ばせる）
        ROW_NUMBER()     OVER (ORDER BY trade_date) AS rn
    FROM prices
    WHERE code = @code
),
horizons AS (
    -- h を増やすときはここに行を足す（5＝1週・20＝4週・65＝13週）
    SELECT h FROM (VALUES (5), (20), (65)) AS v(h)
),
judged AS (
    SELECT
        hz.h,
        b.trade_date,
        CASE WHEN b.close_price > b.ma25 THEN 1 ELSE 0 END AS pred_up,
        CASE WHEN f.close_price > b.close_price THEN 1 ELSE 0 END AS actual_up
    FROM base AS b
    CROSS JOIN horizons AS hz
    -- h 取引日後の行と組む。まだ無い日（直近 h 日）は JOIN で落ちる
    JOIN base AS f ON f.rn = b.rn + hz.h
    WHERE b.ma_rows = 25
)
SELECT
    h,
    COUNT(*)                                             AS days,
    MIN(trade_date)                                      AS first_day,
    MAX(trade_date)                                      AS last_day,
    SUM(CASE WHEN pred_up = actual_up THEN 1 ELSE 0 END) AS rule_hits,
    CAST(100.0 * SUM(CASE WHEN pred_up = actual_up THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5, 1)) AS rule_hit_pct,
    SUM(actual_up)                                       AS base_hits,
    CAST(100.0 * SUM(actual_up) / COUNT(*) AS DECIMAL(5, 1)) AS base_hit_pct,
    SUM(pred_up)                                         AS pred_up_days
FROM judged
GROUP BY h
ORDER BY h;

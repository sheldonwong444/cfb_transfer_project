-- Step 1: Clean passing feed columns
WITH combined_passing AS (
  SELECT * EXCEPT (hit_qb, spike, target_fumble) 
  FROM `cfbproject-499918.cfb_transfers_and_plays.2024_passing_feed`
),

-- Step 2: Join play feed with cleaned passing feed
passing_plays_full AS (
  SELECT 
    p.pff_PLAYID,
    p.pff_GAMEID,
    p.pff_EXPECTED_POINTS_ADDED,
    cp.target_name,
    cp.offense,
    cp.week,
    cp.down,
    cp.quarter,
    cp.distance,
    cp.game_clock,
    COALESCE(cp.completion, 0) AS completion,
    COALESCE(cp.yards, 0) AS yards
  FROM `cfbproject-499918.cfb_transfers_and_plays.play_feed_2024_rec` AS p
  LEFT JOIN combined_passing AS cp
    ON p.pff_PLAYID = cp.play_id
  WHERE cp.target_name IS NOT NULL
)

-- Step 3: Run target aggregations and EPA/success metrics
SELECT 
  target_name, 
  COUNT(*) AS targets, 
  ROUND(SUM(pff_EXPECTED_POINTS_ADDED), 4) AS EPA, 
  ROUND(SUM(pff_EXPECTED_POINTS_ADDED) / COUNT(*), 4) AS EPA_per_target, 
  
  -- Success Metrics
  SUM(CASE WHEN pff_EXPECTED_POINTS_ADDED > 0 THEN 1 ELSE 0 END) AS success, 
  ROUND(SUM(CASE WHEN pff_EXPECTED_POINTS_ADDED > 0 THEN 1 ELSE 0 END) / COUNT(*), 4) AS success_rate, 
  
  -- Explosive Play Metrics
  SUM(CASE WHEN pff_EXPECTED_POINTS_ADDED > 0.9 THEN 1 ELSE 0 END) AS explosive,
  ROUND(SUM(CASE WHEN pff_EXPECTED_POINTS_ADDED > 0.9 THEN 1 ELSE 0 END) / COUNT(*), 4) AS explosive_rate, 
  ROUND(AVG(CASE WHEN pff_EXPECTED_POINTS_ADDED > 0.9 THEN pff_EXPECTED_POINTS_ADDED END), 4) AS explosive_epa_per_target,
  ROUND(AVG(CASE WHEN pff_EXPECTED_POINTS_ADDED <= 0.9 THEN pff_EXPECTED_POINTS_ADDED END), 4) AS non_explosive_epa_per_target,
  
  -- Volume Totals
  SUM(completion) AS catches, 
  SUM(yards) AS yards

FROM passing_plays_full
GROUP BY target_name
HAVING targets > 15
ORDER BY targets DESC;
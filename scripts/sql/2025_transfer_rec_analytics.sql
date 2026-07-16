-- Step 1: Clean passing feed columns
WITH combined_passing AS (
  SELECT * EXCEPT (hit_qb, spike, target_fumble) 
  FROM `cfbproject-499918.cfb_transfers_and_plays.passing_feed_part_2`
),

-- Step 2: Join play feed with cleaned passing feed
play_passing_joined AS (
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
  FROM `cfbproject-499918.cfb_transfers_and_plays.play_feed_1` AS p
  LEFT JOIN combined_passing AS cp
    ON p.pff_PLAYID = cp.play_id
  WHERE cp.target_name IS NOT NULL
),

-- Step 3: Join target names with 2025 transfer player metadata
transfers_joined AS (
  SELECT 
    p.*,
    n.* EXCEPT (fullName)
  FROM play_passing_joined AS p
  INNER JOIN `cfbproject-499918.cfb_transfers_and_plays.2025_cfb_rec_transfers` AS n
    ON p.target_name = n.fullName
)

-- Step 4: Run final receiver aggregations and metrics
SELECT 
  target_name,
  position, 
  destination, 
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
  
  -- Catch & Yardage Totals
  SUM(completion) AS catches, 
  SUM(yards) AS yards

FROM transfers_joined
GROUP BY target_name, destination, position
HAVING targets > 15
ORDER BY success_rate DESC;
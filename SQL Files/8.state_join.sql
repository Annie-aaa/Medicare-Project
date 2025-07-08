-- View readmissions_cleaned
SELECT *
FROM readmissions_cleaned;

-- View costs_cleaned
SELECT *
FROM costs_cleaned;

-- Aggregate readmissions_cleaned table by state and condition
-- All facilities will be the same across each state for all conditions (eg 8 facilities in AK at 8 for all conditions)
WITH readmissions_state AS (
    SELECT  state,
            condition,
            COUNT(DISTINCT facility_id) AS number_of_facilities,
            SUM(NULLIF(number_of_discharges, '') :: INT) AS total_discharges,
            SUM(NULLIF(number_of_readmissions, '') :: INT) AS total_readmissions,
            AVG (NULLIF(excess_readmission_ratio, '') :: DECIMAL) AS average_excess_readmissions_ratio
    FROM    readmissions_cleaned
    GROUP BY state, condition
    ORDER BY state, condition
)

-- Aggregate costs_cleaned table by state and condition
-- Facility numbers are different across all state-condition pairs
, costs_state AS (
    SELECT  state,
            condition,
            AVG(NULLIF(average_total_payments, '') :: DECIMAL) AS average_total_payments,
            AVG(NULLIF(average_medicare_payments, '') :: DECIMAL) AS average_medicare_payments
    FROM    costs_cleaned
    GROUP BY state, condition
    ORDER BY state, condition
)

-- Merge and aggregate the tables based on state and condition
-- Previous aggregation ensures acurracy and that duplicates are avoided
-- due to the many to many relationship within original cleaned tables
-- Through inner join, null state was excluded
SELECT  r.state,
        r.condition,
        r.number_of_facilities,
        r.total_discharges,
        r.total_readmissions,
        r.average_excess_readmissions_ratio,
        c.average_total_payments,
        c.average_medicare_payments
FROM    readmissions_state r
LEFT JOIN    costs_state c 
ON      r.state = c.state AND r.condition = c.condition;

-- the merged table was then exported as a csv named rc_merged

-- create a table with only facility number per state for costs
-- Export table as csv named costs_state_facility_count
SELECT  state,
        COUNT(DISTINCT facility_id) AS total_facilities
FROM    costs_cleaned
GROUP BY state
ORDER BY COUNT(DISTINCT facility_id) DESC;

-- Create table to find number of facilities per state where facility id's match between readmissions amd costs table (507 facility id's)
-- Export as a csv named matching_facility_totals
SELECT  c.state,
        COUNT(DISTINCT c.facility_id) AS number_of_facilities
FROM readmissions_cleaned r
INNER JOIN costs_cleaned c 
ON r.facility_id = c.facility_id
GROUP BY c.state
ORDER BY COUNT(DISTINCT c.facility_id) DESC;


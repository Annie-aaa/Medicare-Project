--Exploration
-- Explore costs table
SELECT *
FROM costs;

-- Check range of ruca codes so that I can create a mapping to merge type of area (urban/rural) to costs table
SELECT DISTINCT rndrng_prvdr_ruca 
FROM costs 
ORDER BY rndrng_prvdr_ruca;

-- Where there are null values for ruca codes
-- RESULT: Hartford Hospital, Hospital Of Central Conneticut, Norwalk Hospital,
--  Stamford Hospital, Waterbury Hospital, Yale-New Haven Hospital
SELECT DISTINCT rndrng_prvdr_org_name
FROM costs
WHERE rndrng_prvdr_ruca IS NULL;

--=====================================================================================
-- Cleaning
-- Initial clean of costs table
WITH costs_cleaned AS (
    SELECT 
        -- use cocat operation || to add leading 0 to facility id
        '0' || rndrng_prvdr_ccn AS facility_id, 
        rndrng_prvdr_org_name AS facility_name,
        rndrng_prvdr_city AS city,
        rndrng_prvdr_st AS street,

        -- Add 0 in front of single-unit number (1-9)
        CASE 
        WHEN LENGTH(rndrng_prvdr_state_fips) = 1 THEN 0 || rndrng_prvdr_state_fips
        ELSE rndrng_prvdr_state_fips
        END AS fips_code,

        rndrng_prvdr_zip5 AS zip_code,
        rndrng_prvdr_state_abrvtn AS state,
        rndrng_prvdr_ruca AS ruca_code,
        rndrng_prvdr_ruca_desc AS detailed_ruca_description,
        drg_cd AS drg_code,
        drg_desc AS drg_description, -- drg = diagnosis related group
        
        -- omitting total_discharges as it's limited to 2022 only
        -- was dollar signs when viewing table on website for money totals
        -- but I see after you download the csv it excludes $
        -- otherwise I would've used replace(column, '$', '')
        avg_submtd_cvrd_chrg :: DECIMAL AS average_covered_charges, -- The average charge of all providers' services covered by Medicare for discharges in the DRG. These will vary from hospital to hospital because of differences in hospital charge structures.
        avg_tot_pymt_amt :: DECIMAL AS average_total_payments, -- includes co-payment and deductible amounts that the patient is responsible for and any additional payments by third parties for coordination of benefits.
        avg_mdcr_pymt_amt :: DECIMAL AS average_medicare_payments -- Medicare pays to the provider for Medicare's share of the MS-DRG

    FROM costs
)

-- Merged cleaned costs table with the drg_map conditions and ruca_codes map
-- And filter the entire table for only conditions relevant to readmissions table
, costs_merged AS (  
    SELECT  c.*,
            COALESCE(c.ruca_code, 'No RUCA- Teaching/Research Hospital') AS ruca_code_flag,
            COALESCE(C.detailed_ruca_description, 'No RUCA- Teaching/Research Hospital') AS detailed_ruca_description_flag,
            d.condition,
            -- All null values for RUCA are teaching/research hospitals
            -- They don't have RUCA codes
            -- So I kept the nulls and flagged them as No RUCA - Teaching/Research Hospital
            COALESCE(r.ruca_short_description, 'No RUCA- Teaching/Research Hospital') AS ruca_short_description
    FROM costs_cleaned c
    LEFT JOIN drg_mapping d ON c.drg_code = d.drg_code 
    -- LEFT JOIN ruca_codes_map r ON c.ruca_code = r.ruca_code
    LEFT JOIN ruca_codes_map r 
    ON c.ruca_code = r.ruca_code
    WHERE d.condition IS NOT NULL
)

-- Check each column in costs merged table and Deal with NULL values
-- Only nulls was for ruca_code, ruca_description_detailed, ruca_description_short
-- Flagged above as teaching/research facilities (Using Coalesce)
SELECT *
FROM costs_merged
WHERE ruca_short_description IS NULL; -- column names replaced to check each column

--===========================================================================================

-- Check for duplicate rows
-- Initial clean of costs table
WITH costs_cleaned AS (
    SELECT 
        -- use cocat operation || to add leading 0 to facility id
        '0' || rndrng_prvdr_ccn AS facility_id, 
        rndrng_prvdr_org_name AS facility_name,
        rndrng_prvdr_city AS city,
        rndrng_prvdr_st AS street,

        -- Add 0 in front of single-unit number (1-9)
        CASE 
        WHEN LENGTH(rndrng_prvdr_state_fips) = 1 THEN 0 || rndrng_prvdr_state_fips
        ELSE rndrng_prvdr_state_fips
        END AS fips_code,

        rndrng_prvdr_zip5 AS zip_code,
        rndrng_prvdr_state_abrvtn AS state,
        rndrng_prvdr_ruca AS ruca_code,
        rndrng_prvdr_ruca_desc AS detailed_ruca_description,
        drg_cd AS drg_code,
        drg_desc AS drg_description, -- drg = diagnosis related group
        
        -- omitting total_discharges as it's limited to 2022 only
        -- was dollar signs when viewing table on website for money totals
        -- but I see after you download the csv it excludes $
        -- otherwise I would've used replace(column, '$', '')
        avg_submtd_cvrd_chrg :: DECIMAL AS average_covered_charges, -- The average charge of all providers' services covered by Medicare for discharges in the DRG. These will vary from hospital to hospital because of differences in hospital charge structures.
        avg_tot_pymt_amt :: DECIMAL AS average_total_payments, -- includes co-payment and deductible amounts that the patient is responsible for and any additional payments by third parties for coordination of benefits.
        avg_mdcr_pymt_amt :: DECIMAL AS average_medicare_payments -- Medicare pays to the provider for Medicare's share of the MS-DRG

    FROM costs
)

-- Merged cleaned costs table with the drg_map conditions and ruca_codes map
-- And filter the entire table for only conditions relevant to readmissions table
, costs_merged AS (  
    SELECT  c.*,
            COALESCE(c.ruca_code, 'No RUCA- Teaching/Research Hospital') AS ruca_code_flag,
            COALESCE(C.detailed_ruca_description, 'No RUCA- Teaching/Research Hospital') AS detailed_ruca_description_flag,
            d.condition,
            -- All null values for RUCA are teaching/research hospitals
            -- They don't have RUCA codes
            -- So I kept the nulls and flagged them as No RUCA - Teaching/Research Hospital
            COALESCE(r.ruca_short_description, 'No RUCA- Teaching/Research Hospital') AS ruca_short_description
    FROM costs_cleaned c
    LEFT JOIN drg_mapping d ON c.drg_code = d.drg_code 
    -- LEFT JOIN ruca_codes_map r ON c.ruca_code = r.ruca_code
    LEFT JOIN ruca_codes_map r 
    ON c.ruca_code = r.ruca_code
    WHERE d.condition IS NOT NULL
)

-- Check for duplicate rows
-- RESULT: No Duplicate Rows
SELECT facility_id, facility_name, city, street, fips_code, zip_code, state, 
       ruca_code, detailed_ruca_description, drg_code, drg_description, 
       average_covered_charges, average_total_payments, average_medicare_payments, 
       ruca_code_flag, detailed_ruca_description_flag, condition, ruca_short_description, 
       COUNT(*) AS duplicate_count
FROM costs_merged
GROUP BY facility_id, facility_name, city, street, fips_code, zip_code, state, 
         ruca_code, detailed_ruca_description, drg_code, drg_description, 
         average_covered_charges, average_total_payments, average_medicare_payments, 
         ruca_code_flag, detailed_ruca_description_flag, condition, ruca_short_description
HAVING COUNT(*) > 1;

--=============================================================================================
-- Outlier detection and handling

-- Initial clean of costs table
WITH costs_cleaned AS (
    SELECT 
        -- use cocat operation || to add leading 0 to facility id
        '0' || rndrng_prvdr_ccn AS facility_id, 
        rndrng_prvdr_org_name AS facility_name,
        rndrng_prvdr_city AS city,
        rndrng_prvdr_st AS street,

        -- Add 0 in front of single-unit number (1-9)
        CASE 
        WHEN LENGTH(rndrng_prvdr_state_fips) = 1 THEN 0 || rndrng_prvdr_state_fips
        ELSE rndrng_prvdr_state_fips
        END AS fips_code,

        rndrng_prvdr_zip5 AS zip_code,
        rndrng_prvdr_state_abrvtn AS state,
        rndrng_prvdr_ruca AS ruca_code,
        rndrng_prvdr_ruca_desc AS detailed_ruca_description,
        drg_cd AS drg_code,
        drg_desc AS drg_description, -- drg = diagnosis related group
        
        -- omitting total_discharges as it's limited to 2022 only
        -- was dollar signs when viewing table on website for money totals
        -- but I see after you download the csv it excludes $
        -- otherwise I would've used replace(column, '$', '')
        avg_submtd_cvrd_chrg :: DECIMAL AS average_covered_charges, -- The average charge of all providers' services covered by Medicare for discharges in the DRG. These will vary from hospital to hospital because of differences in hospital charge structures.
        avg_tot_pymt_amt :: DECIMAL AS average_total_payments, -- includes co-payment and deductible amounts that the patient is responsible for and any additional payments by third parties for coordination of benefits.
        avg_mdcr_pymt_amt :: DECIMAL AS average_medicare_payments -- Medicare pays to the provider for Medicare's share of the MS-DRG

    FROM costs
)

-- Merged cleaned costs table with the drg_map conditions and ruca_codes map
-- And filter the entire table for only conditions relevant to readmissions table
, costs_merged AS (  
    SELECT  c.*,
            COALESCE(c.ruca_code, 'No RUCA- Teaching/Research Hospital') AS ruca_code_flag,
            COALESCE(C.detailed_ruca_description, 'No RUCA- Teaching/Research Hospital') AS detailed_ruca_description_flag,
            d.condition,
            -- All null values for RUCA are teaching/research hospitals
            -- They don't have RUCA codes
            -- So I kept the nulls and flagged them as No RUCA - Teaching/Research Hospital
            COALESCE(r.ruca_short_description, 'No RUCA- Teaching/Research Hospital') AS ruca_short_description
    FROM costs_cleaned c
    LEFT JOIN drg_mapping d ON c.drg_code = d.drg_code 
    -- LEFT JOIN ruca_codes_map r ON c.ruca_code = r.ruca_code
    LEFT JOIN ruca_codes_map r 
    ON c.ruca_code = r.ruca_code
    WHERE d.condition IS NOT NULL
)


-- IQR Method for average_covered_charges, average_total_payments and
-- average_medicare_payments
-- Will check across facility and 
 
-- To determine whether the data is normally distributed or skewed, I'll check 
-- skewness
--  ≈ 0 → (between -1 and 1) Data is approximately normal.
--  > 0 → Right-skewed (long tail on the right, meaning high-cost outliers).
--  < 0 → Left-skewed (long tail on the left, meaning unusually low payments).
-- <-1 highly skewed to left, > 1 highly skewed to the right

-- average_covered_Charges
-- RESULT: 0.89... skewness = positive skew (right-skewed), 
-- but it's within the acceptable range for normality (-1 to 1). z-score
SELECT 
    AVG(average_covered_charges) AS charges_mean,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY average_covered_charges) AS charges_median,
    STDDEV(average_covered_charges) AS charged_stddev,
    (3 * (AVG(average_covered_charges) - PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY average_covered_charges))) 
    / NULLIF(STDDEV(average_covered_charges), 0) AS charges_skewness
FROM costs_merged;

-- average_total_payments
-- RESULT: 0.87... skewness = positive skew (right-skewed), 
-- but it's within the acceptable range for normality (-1 to 1). z-score
SELECT 
    AVG(average_total_payments) AS total_mean,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY average_total_payments) AS total_median,
    STDDEV(average_total_payments) AS total_stddev,
    (3 * (AVG(average_total_payments) - PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY average_total_payments))) 
    / NULLIF(STDDEV(average_total_payments), 0) AS total_skewness
FROM costs_merged;

-- average_medicare_payments
-- RESULT: 0.81... skewness = positive skew (right-skewed), 
-- but it's within the acceptable range for normality (-1 to 1). z-score

SELECT 
    AVG(average_medicare_payments) AS mean_value,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY average_medicare_payments) AS median_value,
    STDDEV(average_medicare_payments) AS stddev_value,
    (3 * (AVG(average_medicare_payments) - PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY average_medicare_payments))) 
    / NULLIF(STDDEV(average_medicare_payments), 0) AS skewness
FROM costs_merged;

-- Using Z-Score
--______________________________________________________________________
-- Initial clean of costs table
WITH costs_cleaned AS (
    SELECT 
        -- use cocat operation || to add leading 0 to facility id
        '0' || rndrng_prvdr_ccn AS facility_id, 
        rndrng_prvdr_org_name AS facility_name,
        rndrng_prvdr_city AS city,
        rndrng_prvdr_st AS street,

        -- Add 0 in front of single-unit number (1-9)
        CASE 
        WHEN LENGTH(rndrng_prvdr_state_fips) = 1 THEN 0 || rndrng_prvdr_state_fips
        ELSE rndrng_prvdr_state_fips
        END AS fips_code,

        rndrng_prvdr_zip5 AS zip_code,
        rndrng_prvdr_state_abrvtn AS state,
        rndrng_prvdr_ruca AS ruca_code,
        rndrng_prvdr_ruca_desc AS detailed_ruca_description,
        drg_cd AS drg_code,
        drg_desc AS drg_description, -- drg = diagnosis related group
        
        -- omitting total_discharges as it's limited to 2022 only
        -- was dollar signs when viewing table on website for money totals
        -- but I see after you download the csv it excludes $
        -- otherwise I would've used replace(column, '$', '')
        avg_submtd_cvrd_chrg :: DECIMAL AS average_covered_charges, -- The average charge of all providers' services covered by Medicare for discharges in the DRG. These will vary from hospital to hospital because of differences in hospital charge structures.
        avg_tot_pymt_amt :: DECIMAL AS average_total_payments, -- includes co-payment and deductible amounts that the patient is responsible for and any additional payments by third parties for coordination of benefits.
        avg_mdcr_pymt_amt :: DECIMAL AS average_medicare_payments -- Medicare pays to the provider for Medicare's share of the MS-DRG

    FROM costs
)

-- Merged cleaned costs table with the drg_map conditions and ruca_codes map
-- And filter the entire table for only conditions relevant to readmissions table
, costs_merged AS (  
    SELECT  c.*,
            COALESCE(c.ruca_code, 'No RUCA- Teaching/Research Hospital') AS ruca_code_flag,
            COALESCE(C.detailed_ruca_description, 'No RUCA- Teaching/Research Hospital') AS detailed_ruca_description_flag,
            d.condition,
            -- All null values for RUCA are teaching/research hospitals
            -- They don't have RUCA codes
            -- So I kept the nulls and flagged them as No RUCA - Teaching/Research Hospital
            COALESCE(r.ruca_short_description, 'No RUCA- Teaching/Research Hospital') AS ruca_short_description
    FROM costs_cleaned c
    LEFT JOIN drg_mapping d ON c.drg_code = d.drg_code 
    -- LEFT JOIN ruca_codes_map r ON c.ruca_code = r.ruca_code
    LEFT JOIN ruca_codes_map r 
    ON c.ruca_code = r.ruca_code
    WHERE d.condition IS NOT NULL
)
, stats AS (
    -- z-score = how many std away from the mean, more than 2 or 3 away is outlier
    -- z-score = column value- mean / std
    SELECT 
        AVG(average_covered_charges) AS mean_charge,
        STDDEV(average_covered_charges) AS std_charge,
        AVG(average_total_payments) AS mean_total,
        STDDEV(average_total_payments) AS std_total,
        AVG(average_medicare_payments) AS mean_medicare,
        STDDEV(average_medicare_payments) AS std_medicare
    FROM costs_merged
)

-- Flagging Outliers using z-score
-- This is the final cleaned table for costs
-- Will be exported
, costs_final AS (
    SELECT 
        c.*,
        (c.average_covered_charges - s.mean_charge) / NULLIF(s.std_charge, 0) AS z_score_charges,
        (c.average_total_payments - s.mean_total) / NULLIF(s.std_total, 0) AS z_score_total,
        (c.average_medicare_payments - s.mean_medicare) / NULLIF(s.std_medicare, 0) AS z_score_medicare,
        -- add a column for each showing outlier status depending on z-score
        -- average_covered_charges
        CASE
        WHEN ((c.average_covered_charges - s.mean_charge) / NULLIF(s.std_charge, 0)) > 3 THEN 'High Outlier'
        WHEN ((c.average_covered_charges - s.mean_charge) / NULLIF(s.std_charge, 0)) < -3 THEN 'Low Outlier'
        ELSE 'Normal'
        END AS charges_z_status,
        -- average_total_payments
        CASE
        WHEN ((c.average_total_payments - s.mean_total) / NULLIF(s.std_total, 0)) > 3 THEN 'High Outlier'
        WHEN ((c.average_total_payments - s.mean_total) / NULLIF(s.std_total, 0)) < -3 THEN 'Low Outlier'
        ELSE 'Normal'
        END AS total_z_status,
        -- average_medicare_payments
        CASE
        WHEN ((c.average_medicare_payments - s.mean_medicare) / NULLIF(s.std_medicare, 0) ) > 3 THEN 'High Outlier'
        WHEN ((c.average_medicare_payments - s.mean_medicare) / NULLIF(s.std_medicare, 0) ) < -3 THEN 'Low Outlier'
        ELSE 'Normal'
        END AS medicare_z_status
    FROM costs_merged c
    JOIN stats s ON TRUE
)
-- Create cost_final table
CREATE TABLE costs_cleaned (
    facility_id VARCHAR(10),
    facility_name VARCHAR(100),
    city VARCHAR(100),
    street VARCHAR(50),
    fips_code VARCHAR(5),
    zip_code VARCHAR(5),
    state VARCHAR(5),
    ruca_code VARCHAR(20),
    detailed_ruca_description VARCHAR(150),
    drg_code VARCHAR(5),
    drg_description VARCHAR(150),
    average_covered_charges VARCHAR(20),
    average_total_payments VARCHAR(20),
    average_medicare_payments VARCHAR(20),
    ruca_code_flag VARCHAR(50),
    detailed_ruca_description_flag VARCHAR(150),
    condition VARCHAR(50),
    ruca_short_description VARCHAR(50),
    z_score_charges VARCHAR(50),
    z_score_total VARCHAR(50),
    z_score_medicare VARCHAR(50),
    charges_z_status VARCHAR(20),
    total_z_status VARCHAR(20),
    medicare_z_status VARCHAR(20)
);

-- Load costs_cleaned table
COPY costs_cleaned (facility_id,
    facility_name,
    city,
    street,
    fips_code,
    zip_code,
    state,
    ruca_code,
    detailed_ruca_description,
    drg_code,
    drg_description,
    average_covered_charges,
    average_total_payments,
    average_medicare_payments,
    ruca_code_flag,
    detailed_ruca_description_flag,
    condition,
    ruca_short_description,
    z_score_charges,
    z_score_total,
    z_score_medicare,
    charges_z_status,
    total_z_status,
    medicare_z_status
)
FROM 'C:\Desktop\Data Projects\Portfolio Projects\SQL&Tableau\Medicare\costs_cleaned.csv'
WITH (FORMAT csv, HEADER true);

-- Filtering and examining outliers
-- RESULTS: almost 600 of the 611 rows are ruca = 1.0
-- So metropolitan areas = more expensive, hence, I'll filter those ones out
-- and examine the other 24 more closely:
-- RESULTS: Of the 24, 22 rows are for CABG = high cost
--          Other 2 is for hip/knee micro and metropolitan
--          Four of the 24 is small town CABG
--          Will keep and flag outliera
SELECT  *
FROM    costs_final
WHERE   (charges_z_status != 'Normal'
OR      total_z_status != 'Normal'
OR      medicare_z_status != 'Normal')
AND ruca_code != '1.0'
;






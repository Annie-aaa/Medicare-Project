-- Check readmissions table
SELECT *
FROM readmissions;

-- =========================================================
-- Cleanup readmissions table for analysis
-- Standardizes hospital names, converts data types, handles missing values, checks for duplicates
-- =========================================================
WITH readmissions_cleaned AS(
    SELECT  
    INITCAP(facility_name) AS facility_name,  -- Standardize hospital names to match costs table
    facility_id,
    state,
    measure_name,
    
    -- Convert 'N/A' to NULL and cast data type from TEXT to INTEGER
    NULLIF(number_of_discharges, 'N/A')::INT AS number_of_discharges,  
    
    -- Convert 'N/A' to NULL and cast data type from TEXT to DECIMAL
    NULLIF(excess_readmission_ratio, 'N/A')::DECIMAL AS excess_readmission_ratio,  
    NULLIF(predicted_readmission_rate, 'N/A')::DECIMAL AS predicted_readmission_rate,
    NULLIF(expected_readmission_rate, 'N/A')::DECIMAL AS expected_readmission_rate,

    -- Convert 'N/A' to NULL, change 'Too Few to Report' to 0, and cast to INTEGER
    (CASE 
        WHEN number_of_readmissions = 'N/A' THEN NULL
        WHEN number_of_readmissions = 'Too Few to Report' THEN '0' 
        ELSE number_of_readmissionS 
    END) :: INT AS number_of_readmissions,  -- Convert remaining values to integer

    -- Convert VARCHAR date to DATE format (PostgreSQL uses 'YYYY-MM-DD' internally)
    TO_DATE(start_date, 'MM/DD/YYYY') AS start_date,  
    TO_DATE(end_date, 'MM/DD/YYYY') AS end_date  

FROM readmissions
)

-- Check readmissions_cleaned for duplicates, returns no data so there's no duplicates
SELECT *, COUNT(*) AS duplicate_count
FROM readmissions_cleaned
GROUP BY facility_name, facility_id, state, measure_name, 
         number_of_discharges, excess_readmission_ratio, 
         predicted_readmission_rate, expected_readmission_rate,
         number_of_readmissions, start_date, end_date
HAVING COUNT(*) > 1;

-- ==============================================================================
-- HANDLING OUTLIERS
-- ==============================================================================
-- Check readmissions_cleaned for outliers

-- Readmissions_Cleaned Table
WITH readmissions_cleaned AS (
    SELECT  
        INITCAP(facility_name) AS facility_name,  -- Standardize hospital names
        facility_id,
        state,
        measure_name,

        -- Convert 'N/A' to NULL and cast to correct types
        NULLIF(number_of_discharges, 'N/A')::INT AS number_of_discharges,  
        NULLIF(excess_readmission_ratio, 'N/A')::DECIMAL AS excess_readmission_ratio,  
        NULLIF(predicted_readmission_rate, 'N/A')::DECIMAL AS predicted_readmission_rate,
        NULLIF(expected_readmission_rate, 'N/A')::DECIMAL AS expected_readmission_rate,
        
        (CASE 
            WHEN number_of_readmissions = 'N/A' THEN NULL
            WHEN number_of_readmissions = 'Too Few to Report' THEN '0' 
            ELSE number_of_readmissions 
        END)::INT AS number_of_readmissions,

        -- Convert dates
        TO_DATE(start_date, 'MM/DD/YYYY') AS start_date,  
        TO_DATE(end_date, 'MM/DD/YYYY') AS end_date  

    FROM readmissions
)

-- Stats Table: Calculate IQR & Bounds for All Measures
, stats AS (
    SELECT 
        measure_name,

        -- Compute Q1 & Q3 for each numeric measure
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY excess_readmission_ratio) AS Q1_excess,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY excess_readmission_ratio) AS Q3_excess,
        
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY expected_readmission_rate) AS Q1_expected,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY expected_readmission_rate) AS Q3_expected,

        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY predicted_readmission_rate) AS Q1_predicted,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY predicted_readmission_rate) AS Q3_predicted,

        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY number_of_discharges) AS Q1_discharges,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY number_of_discharges) AS Q3_discharges,

        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY number_of_readmissions) AS Q1_readmissions,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY number_of_readmissions) AS Q3_readmissions
    FROM readmissions_cleaned
    GROUP BY measure_name
)

-- Final Query: Identify Outliers for All Five Measures
SELECT r.facility_id, 
       r.facility_name, 
       r.measure_name, 
       r.state,

       -- Values for each measure
       -- excess_readmission_ratio
       r.excess_readmission_ratio, s.Q1_excess, s.Q3_excess,
       (s.Q3_excess - s.Q1_excess) AS IQR_excess,
       (s.Q1_excess - 1.5 * (s.Q3_excess - s.Q1_excess)) AS lower_bound_excess,
       (s.Q3_excess + 1.5 * (s.Q3_excess - s.Q1_excess)) AS upper_bound_excess,
       CASE 
           WHEN r.excess_readmission_ratio < (s.Q1_excess - 1.5 * (s.Q3_excess - s.Q1_excess)) THEN 'Low Outlier'
           WHEN r.excess_readmission_ratio > (s.Q3_excess + 1.5 * (s.Q3_excess - s.Q1_excess)) THEN 'High Outlier'
           ELSE 'Normal'
       END AS outlier_status_excess,

        -- expected_readmission_rate
       r.expected_readmission_rate, s.Q1_expected, s.Q3_expected,
       (s.Q3_expected - s.Q1_expected) AS IQR_expected,
       (s.Q1_expected - 1.5 * (s.Q3_expected - s.Q1_expected)) AS lower_bound_expected,
       (s.Q3_expected + 1.5 * (s.Q3_expected - s.Q1_expected)) AS upper_bound_expected,
       CASE 
           WHEN r.expected_readmission_rate < (s.Q1_expected - 1.5 * (s.Q3_expected - s.Q1_expected)) THEN 'Low Outlier'
           WHEN r.expected_readmission_rate > (s.Q3_expected + 1.5 * (s.Q3_expected - s.Q1_expected)) THEN 'High Outlier'
           ELSE 'Normal'
       END AS outlier_status_expected,

        -- predicted_readmission_rate
       r.predicted_readmission_rate, s.Q1_predicted, s.Q3_predicted,
       (s.Q3_predicted - s.Q1_predicted) AS IQR_predicted,
       (s.Q1_predicted - 1.5 * (s.Q3_predicted - s.Q1_predicted)) AS lower_bound_predicted,
       (s.Q3_predicted + 1.5 * (s.Q3_predicted - s.Q1_predicted)) AS upper_bound_predicted,
       CASE 
           WHEN r.predicted_readmission_rate < (s.Q1_predicted - 1.5 * (s.Q3_predicted - s.Q1_predicted)) THEN 'Low Outlier'
           WHEN r.predicted_readmission_rate > (s.Q3_predicted + 1.5 * (s.Q3_predicted - s.Q1_predicted)) THEN 'High Outlier'
           ELSE 'Normal'
       END AS outlier_status_predicted,

        -- number_of_discharges
       r.number_of_discharges, s.Q1_discharges, s.Q3_discharges,
       (s.Q3_discharges - s.Q1_discharges) AS IQR_discharges,
       (s.Q1_discharges - 1.5 * (s.Q3_discharges - s.Q1_discharges)) AS lower_bound_discharges,
       (s.Q3_discharges + 1.5 * (s.Q3_discharges - s.Q1_discharges)) AS upper_bound_discharges,
       CASE 
           WHEN r.number_of_discharges < (s.Q1_discharges - 1.5 * (s.Q3_discharges - s.Q1_discharges)) THEN 'Low Outlier'
           WHEN r.number_of_discharges > (s.Q3_discharges + 1.5 * (s.Q3_discharges - s.Q1_discharges)) THEN 'High Outlier'
           ELSE 'Normal'
       END AS outlier_status_discharges,

        -- number_of_readmissions
       r.number_of_readmissions, s.Q1_readmissions, s.Q3_readmissions,
       (s.Q3_readmissions - s.Q1_readmissions) AS IQR_readmissions,
       (s.Q1_readmissions - 1.5 * (s.Q3_readmissions - s.Q1_readmissions)) AS lower_bound_readmissions,
       (s.Q3_readmissions + 1.5 * (s.Q3_readmissions - s.Q1_readmissions)) AS upper_bound_readmissions,
       CASE 
           WHEN r.number_of_readmissions < (s.Q1_readmissions - 1.5 * (s.Q3_readmissions - s.Q1_readmissions)) THEN 'Low Outlier'
           WHEN r.number_of_readmissions > (s.Q3_readmissions + 1.5 * (s.Q3_readmissions - s.Q1_readmissions)) THEN 'High Outlier'
           ELSE 'Normal'
       END AS outlier_status_readmissions

FROM readmissions_cleaned r
JOIN stats s ON r.measure_name = s.measure_name

-- Only Show Outliers for All Measures
-- Also change measure_name each time to order by descending for each measure so I can 
-- Get the min and max for each measure (e.g. number_of_discharges) of each measure_name (e.g. 'READM-30-AMI-HRRP')
-- I listed outlier info for each below the query

WHERE 
   ( r.excess_readmission_ratio < (s.Q1_excess - 1.5 * (s.Q3_excess - s.Q1_excess)) 
 OR r.excess_readmission_ratio > (s.Q3_excess + 1.5 * (s.Q3_excess - s.Q1_excess))
 OR r.expected_readmission_rate < (s.Q1_expected - 1.5 * (s.Q3_expected - s.Q1_expected))
 OR r.expected_readmission_rate > (s.Q3_expected + 1.5 * (s.Q3_expected - s.Q1_expected))
 OR r.predicted_readmission_rate < (s.Q1_predicted - 1.5 * (s.Q3_predicted - s.Q1_predicted))
 OR r.predicted_readmission_rate > (s.Q3_predicted + 1.5 * (s.Q3_predicted - s.Q1_predicted))
 OR r.number_of_discharges < (s.Q1_discharges - 1.5 * (s.Q3_discharges - s.Q1_discharges))
 OR r.number_of_discharges > (s.Q3_discharges + 1.5 * (s.Q3_discharges - s.Q1_discharges))
 OR r.number_of_readmissions < (s.Q1_readmissions - 1.5 * (s.Q3_readmissions - s.Q1_readmissions))
 OR r.number_of_readmissions > (s.Q3_readmissions + 1.5 * (s.Q3_readmissions - s.Q1_readmissions))
   )
-- section I change each time:
AND r.measure_name = 'READM-30-CABG-HRRP'
ORDER BY r.number_of_readmissions 
;

--=======================================================================
-- OUTLIER INFORMATION
-- =====================================================================

-- AMI (Heart Attack)
-- ---------------------
-- 1. excess_readmission_ratio

-- upper bound = 1.17375...
-- max = 1.2809
-- note: max is very close to the upper bound so not a data entry error, will keep higher outlier

-- min = 0.7224
-- lower bound = 0.82814...
-- note: min is also very close to lower bound so not a data entry erro, will keep lower outliers

--__________________________
-- 2. expected_readmissions_rate

-- upper bound = 17.275475
-- max = 21.4598
-- note: almost 40 other values that are outside of upper bounds
--       max is a statistical outlier but not necessarily incorrect
--       typical 30-day readmission rates for AMI is ~15-18% as per CMS
--       Since there are 40+ upper outliers, removing them might hide valuable 
--       insights about facilities with extremely high readmissions.
--       so keep outliers but flag them as high outliers

-- min = 8.5722
-- lower bound = 9.478075...
-- note: min is the only lower outlier, next value is 10.2756 which is within bounds
--       suggests that the hospital has a significantly lower readmission rate than 
--       expected but is not necessarily a data entry error
--       will also keep but flag

--__________________________
-- 3. predicted_readmissions_rate

-- upper bound = 18.5667...
-- max = 23.0214
-- note: not a daty entry error, will keep outliers to identify significantly 
--       higher rates

-- min = 8.1579
-- lower bound = 8.32012....
-- note: not a daty entry error, will keep outliers to identify significantly 
--       lower rate (only one lower outlier)

--__________________________
--4. number_of_discharges

-- upper bound = 530.5
-- max = 1134
-- note: high number of discharges could be due to certain facilities having a
--       larger amount of patients than usual so not necessarily a data entry error
--       keep and flag

-- min = NO OUTLIERS (lowest is 37 and its still above a negative)
-- lower bound = -137.5
-- note: no lower outliers

--__________________________
--5. number_of_readmissions

-- upper bound = 80
-- max = 180
-- note: max outlier is not a data entry error as some hospitals may be
--       larger in size or specialise in treating sicker patients
--       keep but flag

-- lower bound = -48
-- min = no lower outliers (lowest value is 0)
-- note: keep and flag

--_________________________

-- HF (heart failure)
--_________________________
--1. excess_readmission_ratio

-- upper bound = 1.16725...
-- max = 1.3070
-- note: not a data entry error

-- min = 0.7390
-- lower bound = 0.83424...
-- note: not a data entry error

--_____________________________
--2. expected_readmission_rate

-- upper bound = 22.80503...
-- max = 
-- note: not a data entry error

-- min = 14.4268
-- lower bound = 16.0675...
-- note: not a data entry error

--_______________________________
--3. predicted_readmission_rate

-- upper bound = 27.2973
-- max = 24.80456....
-- note: not a data entry error

-- lower bound = 13.9684....
-- min = 13.7587
-- note: not a data entry error

--_______________________________
--4. number_of_readmissions

-- upper bound = 196
-- max = 877
-- note: Given that AdventHealth Orlando is the second-largest hospital in 
--       Florida and a major research/teaching hospital (trainees on severe cases), 
--       870 readmissions is likely normal rather than a data entry error.

-- min = 0
-- lower bound = -84
-- note: no data entry errors

--________________________________
--5. number_of_discharges

-- upper bound = 1019.375
-- max = 3490
-- note: Christiana Hospital is a 906-bed nationally 
--       ranked, non-profit, tertiary, research and academic medical center 
--       located in Stanton, Newark, Delaware, (largest in Delaware)
--       servicing the entire Delaware area and parts of southern New Jersey.
--       no data entry errors

-- min = 32
-- lower bound = -379.625
-- note: no data entry errors

--_________________________________

-- PN (pneumonia)
--_________________________________
--1. excess_readmissions_ratio

-- upper bound = 1.1544
-- max = 1.4919
-- note: not a data entry error

-- min = 0.7803
-- lower bound = 0.84400...
-- note: not a data entry error

--_________________________________
--2. expected_readmission_rate

-- upper bound = 19.6159....
-- max = 23.4185
-- note: not a data entry error

-- min = 10.5768
-- lower bound = 12.2533...
-- note: not a data entry error

--__________________________________
--3. predicted_readmission_rate

-- upper bound = 20.9752...
-- max = 25.7715
-- note: not a data entry error

-- min = no lower outliers (lowest 10.8774)
-- lower bound = 10.8214...
-- note: not a data entry error

--___________________________________
--4. number_of_discharges

-- upper bound = 800.5
-- max = 3258
-- note: no data entry error

-- min = no lower outliers (51 lowest)
-- lower bound = -243.5
-- note: no data entry error

--___________________________________
--5. number_of_readmissions

-- upper bound = 128.5
-- max = 627
-- note: not a data entry error

-- min = 0
-- lower bound = -51.5
-- note: not a data entry error, remember too few to report was changed to 0

--___________________________________

--  COPD (chronic obstructive pulmonary disease)
--______________________________________________
--1. excess_readmissions_ratio

-- upper bound = 1.13486...
-- max = 1.2768
-- note: not a data entry error

-- min = 0.8087
-- lower bound = 0.86561...
-- note: not a data entry error

--______________________________________________
--2. predicted_readmission_rate

-- upper bound = 23.7954...
-- max = 27.7095
-- note: not a data entry error

-- min = 12.0171
-- lower bound = 12.6697...
-- note: not a data entry error

--______________________________________________
--3. expected_readmission_rate

-- upper bound = 22.7206...
-- max = 25.3942
-- note: not a data entry error

-- min = 12.3642
-- lower bound = 13.7801...
-- note: not a data entry error

--______________________________________________
--4. number_of_discharges

-- upper bound = 302.5
-- max = 730
-- note: not a data entry error

-- min = no lower outlier (29 lowest)
-- lower bound = -45.5
-- note: not a data entry error

--______________________________________________
--5. number_of_readmissions

-- upper bound = 67.5
-- max = 152
-- note: not a data entry error

-- min = no lower outlier (0 lowest)
-- lower bound = -40.5
-- note: not a data entry error

--______________________________________________

--CABG (coronary artery bypass graft surgery)
--_______________________________________________
--1. excess_readmission_ratio

-- upper bound = 1.199075
-- max = 1.3451
-- note: not a data entry error

-- min = 0.7443
-- lower bound = 0.79727...
-- note: not a data entry error


--_______________________________________________
--2. predicted_readmission_rate

-- upper bound = 14.3566...
-- max = 16.7390
-- note: not a data entry error

-- min = 7.5307
-- lower bound = 6.88985
-- note: not a data entry error

--_______________________________________________
--3. expected_readmission_rate

-- upper bound = 13.42224...
-- max = 15.4523
-- note: not a data entry error

-- min = 8.6910
-- lower bound = 7.76305
-- note: not a data entry error

--_______________________________________________
--4. number_of_discharges

-- upper bound = 371
-- max = 788
-- note: not a data entry error, hospitals specialise in heart health

-- min = no lower outlier (35 minimum)
-- lower bound = -53
-- note: no data entry error

--_______________________________________________
--5. number_of_readmissions

-- upper bound = 40
-- max = 79
-- note: not a data entry error, heart hospital = higher CABG

-- min = no lower outlier (minimum 0)
-- lower bound = -24
-- note: no data entry error


--_______________________________________________

-- THA/TKA (hip/knee replacement)
--______________________________________________
--1. excess_readmission_ratio

-- upper bound = 1.3625...
-- max = 1.6430
-- note: not a data entry error

-- min = 0.4779
-- lower bound = 0.6397...
-- note: not a data entry error

--_______________________________________________
--2. predicted_readmission_rate

-- upper bound = 8.1974...
-- max = 9.5878
-- note: not a data entry error

-- min = 1.6742
-- lower bound = 1.7725...
-- note: not a data entry error

--_______________________________________________
--3. expected_readmission_rate

-- upper bound = 7.1176...
-- max = 9.3053
-- note: not a data entry error

-- min = no lower outlier (2.8921 lowest)
-- lower bound = 2.7745...
-- note: not a data entry error

--_______________________________________________
--4. number_of_discharges

-- upper bound = 1000.375
-- max = 4501
-- note: HSS is the world’s leading academic medical center focused on 
--       musculoskeletal health. At its core is Hospital for Special Surgery,
--       ranked No. 1 in orthopedics for 15 years in a row by U.S. News & 
--       World Report. HSS has also been among the top-ranked hospitals for
--       both orthopedics and rheumatology for 33 consecutive years.
--      Therefore, high number makes sense as they specialise in this type
--      of surgery, they will have higher discharges for hip/knee surgeries
--      than general hospitals
--      not a data entry error

-- min = no lower outliers (lowest 84)
-- lower bound = -430.625
-- note: not a data entry error

--_______________________________________________
--5. number_of_readmissions

-- upper bound = 0***
-- max = 35
-- note:

-- min =
-- lower bound = 0***
-- note: 

--note: Check counts of number_of_Readmissions to find 0 has 1291, 
--      null has 1497 
--      and others hardly add up to a count of 200
--      so will have to use z-score instead of IQR

-- Check counts for number_of_readmissions
-- Readmissions_Cleaned Table
WITH readmissions_cleaned AS (
    SELECT  
        INITCAP(facility_name) AS facility_name,  -- Standardize hospital names
        facility_id,
        state,
        measure_name,

        -- Convert 'N/A' to NULL and cast to correct types
        NULLIF(number_of_discharges, 'N/A')::INT AS number_of_discharges,  
        NULLIF(excess_readmission_ratio, 'N/A')::DECIMAL AS excess_readmission_ratio,  
        NULLIF(predicted_readmission_rate, 'N/A')::DECIMAL AS predicted_readmission_rate,
        NULLIF(expected_readmission_rate, 'N/A')::DECIMAL AS expected_readmission_rate,
        
        (CASE 
            WHEN number_of_readmissions = 'N/A' THEN NULL
            WHEN number_of_readmissions = 'Too Few to Report' THEN '0' 
            ELSE number_of_readmissions 
        END)::INT AS number_of_readmissions,

        -- Convert dates
        TO_DATE(start_date, 'MM/DD/YYYY') AS start_date,  
        TO_DATE(end_date, 'MM/DD/YYYY') AS end_date  

    FROM readmissions
)

SELECT number_of_readmissions, COUNT(*)
FROM readmissions_cleaned 
WHERE measure_name = 'READM-30-HIP-KNEE-HRRP' 
GROUP BY number_of_readmissions 
ORDER BY number_of_readmissions;

-- Z Score Method for number_of_readmissions (hip/knee)
-- Find outliers where z-score < 2 or <-2
-- Readmissions_Cleaned Table
WITH readmissions_cleaned AS (
    SELECT  
        INITCAP(facility_name) AS facility_name,  -- Standardize hospital names
        facility_id,
        state,
        measure_name,

        -- Convert 'N/A' to NULL and cast to correct types
        NULLIF(number_of_discharges, 'N/A')::INT AS number_of_discharges,  
        NULLIF(excess_readmission_ratio, 'N/A')::DECIMAL AS excess_readmission_ratio,  
        NULLIF(predicted_readmission_rate, 'N/A')::DECIMAL AS predicted_readmission_rate,
        NULLIF(expected_readmission_rate, 'N/A')::DECIMAL AS expected_readmission_rate,
        
        (CASE 
            WHEN number_of_readmissions = 'N/A' THEN NULL
            WHEN number_of_readmissions = 'Too Few to Report' THEN '0' 
            ELSE number_of_readmissions 
        END)::INT AS number_of_readmissions,

        -- Convert dates
        TO_DATE(start_date, 'MM/DD/YYYY') AS start_date,  
        TO_DATE(end_date, 'MM/DD/YYYY') AS end_date  

    FROM readmissions
)

, z_score_all AS (
    SELECT facility_id, facility_name, state, number_of_readmissions,
        (number_of_readmissions - AVG(number_of_readmissions) OVER()) 
        / NULLIF(STDDEV(number_of_readmissions) OVER(), 0) AS z_score,
        measure_name
    FROM readmissions_cleaned 
    WHERE measure_name = 'READM-30-HIP-KNEE-HRRP'
)
, z_score_outliers AS (
    SELECT *
    FROM z_score_all
    WHERE z_score < -2 OR z_score > 2
    ORDER BY z_score
)

SELECT *
FROM readmissions_cleaned r
LEFT JOIN z_score_outliers z
ON r.facility_id = z.facility_id AND r.measure_name = z.measure_name
ORDER BY r.measure_name
;


-- note: out of 3085 rows of hip-knee data, there are 78 rows of outliers for
--       number_of_readmissions 
--       all of the z-score outliers are above 2
--       can't get rid of the outliers as they are valid data entries
--       with high z-scores that could result from the fact that the facility
--       is a research/learning facility (trainee treating severe cases)
--       or facility is larger than most or specialises in skeletal surgery
--       or has generally low reviews = bad service = high readmissions
--       scanning over the 78 number_of_readmissions column I can see there's
--       no data entry issue and I want to keep all values so that the
--       visualisations show these facilities so stakeholders can investigate
--       further and use this information to make decisions as well



-- Anastasia your next step is to find a way to merge the IQR flags also
-- into this table so it's clean and readable

-- Readmissions_Cleaned Table
WITH readmissions_cleaned AS (
    SELECT  
        INITCAP(facility_name) AS facility_name,  -- Standardize hospital names
        facility_id,
        state,
        measure_name,

        -- Convert 'N/A' to NULL and cast to correct types
        NULLIF(number_of_discharges, 'N/A')::INT AS number_of_discharges,  
        NULLIF(excess_readmission_ratio, 'N/A')::DECIMAL AS excess_readmission_ratio,  
        NULLIF(predicted_readmission_rate, 'N/A')::DECIMAL AS predicted_readmission_rate,
        NULLIF(expected_readmission_rate, 'N/A')::DECIMAL AS expected_readmission_rate,
        
        (CASE 
            WHEN number_of_readmissions = 'N/A' THEN NULL
            WHEN number_of_readmissions = 'Too Few to Report' THEN '0' 
            ELSE number_of_readmissions 
        END)::INT AS number_of_readmissions,

        -- Convert dates
        TO_DATE(start_date, 'MM/DD/YYYY') AS start_date,  
        TO_DATE(end_date, 'MM/DD/YYYY') AS end_date  

    FROM readmissions
)

-- z-score for hip-knee 
, z_score_all AS (
    SELECT facility_id, facility_name, state, number_of_readmissions,
        (number_of_readmissions - AVG(number_of_readmissions) OVER()) 
        / NULLIF(STDDEV(number_of_readmissions) OVER(), 0) AS z_score,
        measure_name
    FROM readmissions_cleaned 
    WHERE measure_name = 'READM-30-HIP-KNEE-HRRP'
)
, z_score_outliers AS (
    SELECT *
    FROM z_score_all
    WHERE z_score < -2 OR z_score > 2
    ORDER BY z_score
)
, z_score_outliers_cleaned AS (
    SELECT  facility_id,
            measure_name,
            z_score AS readmissions_outlier_z_score
    FROM z_score_outliers
)
--IQR tables
-- Stats Table: Calculate IQR & Bounds for All Measures
, stats AS (
    SELECT 
        measure_name,

        -- Compute Q1 & Q3 for each numeric measure
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY excess_readmission_ratio) AS Q1_excess,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY excess_readmission_ratio) AS Q3_excess,
        
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY expected_readmission_rate) AS Q1_expected,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY expected_readmission_rate) AS Q3_expected,

        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY predicted_readmission_rate) AS Q1_predicted,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY predicted_readmission_rate) AS Q3_predicted,

        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY number_of_discharges) AS Q1_discharges,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY number_of_discharges) AS Q3_discharges,

        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY number_of_readmissions) AS Q1_readmissions,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY number_of_readmissions) AS Q3_readmissions
    FROM readmissions_cleaned
    GROUP BY measure_name
)

, stats_outiers AS (
    SELECT r.facility_id, 
       r.facility_name, 
       r.measure_name, 
       r.state,

       -- Values for each measure
       -- excess_readmission_ratio
       r.excess_readmission_ratio, s.Q1_excess, s.Q3_excess,
       (s.Q3_excess - s.Q1_excess) AS IQR_excess,
       (s.Q1_excess - 1.5 * (s.Q3_excess - s.Q1_excess)) AS lower_bound_excess,
       (s.Q3_excess + 1.5 * (s.Q3_excess - s.Q1_excess)) AS upper_bound_excess,
       CASE 
           WHEN r.excess_readmission_ratio < (s.Q1_excess - 1.5 * (s.Q3_excess - s.Q1_excess)) THEN 'Low Outlier'
           WHEN r.excess_readmission_ratio > (s.Q3_excess + 1.5 * (s.Q3_excess - s.Q1_excess)) THEN 'High Outlier'
           ELSE 'Normal'
       END AS outlier_status_excess,

        -- expected_readmission_rate
       r.expected_readmission_rate, s.Q1_expected, s.Q3_expected,
       (s.Q3_expected - s.Q1_expected) AS IQR_expected,
       (s.Q1_expected - 1.5 * (s.Q3_expected - s.Q1_expected)) AS lower_bound_expected,
       (s.Q3_expected + 1.5 * (s.Q3_expected - s.Q1_expected)) AS upper_bound_expected,
       CASE 
           WHEN r.expected_readmission_rate < (s.Q1_expected - 1.5 * (s.Q3_expected - s.Q1_expected)) THEN 'Low Outlier'
           WHEN r.expected_readmission_rate > (s.Q3_expected + 1.5 * (s.Q3_expected - s.Q1_expected)) THEN 'High Outlier'
           ELSE 'Normal'
       END AS outlier_status_expected,

        -- predicted_readmission_rate
       r.predicted_readmission_rate, s.Q1_predicted, s.Q3_predicted,
       (s.Q3_predicted - s.Q1_predicted) AS IQR_predicted,
       (s.Q1_predicted - 1.5 * (s.Q3_predicted - s.Q1_predicted)) AS lower_bound_predicted,
       (s.Q3_predicted + 1.5 * (s.Q3_predicted - s.Q1_predicted)) AS upper_bound_predicted,
       CASE 
           WHEN r.predicted_readmission_rate < (s.Q1_predicted - 1.5 * (s.Q3_predicted - s.Q1_predicted)) THEN 'Low Outlier'
           WHEN r.predicted_readmission_rate > (s.Q3_predicted + 1.5 * (s.Q3_predicted - s.Q1_predicted)) THEN 'High Outlier'
           ELSE 'Normal'
       END AS outlier_status_predicted,

        -- number_of_discharges
       r.number_of_discharges, s.Q1_discharges, s.Q3_discharges,
       (s.Q3_discharges - s.Q1_discharges) AS IQR_discharges,
       (s.Q1_discharges - 1.5 * (s.Q3_discharges - s.Q1_discharges)) AS lower_bound_discharges,
       (s.Q3_discharges + 1.5 * (s.Q3_discharges - s.Q1_discharges)) AS upper_bound_discharges,
       CASE 
           WHEN r.number_of_discharges < (s.Q1_discharges - 1.5 * (s.Q3_discharges - s.Q1_discharges)) THEN 'Low Outlier'
           WHEN r.number_of_discharges > (s.Q3_discharges + 1.5 * (s.Q3_discharges - s.Q1_discharges)) THEN 'High Outlier'
           ELSE 'Normal'
       END AS outlier_status_discharges,

        -- number_of_readmissions
       r.number_of_readmissions, s.Q1_readmissions, s.Q3_readmissions,
       (s.Q3_readmissions - s.Q1_readmissions) AS IQR_readmissions,
       (s.Q1_readmissions - 1.5 * (s.Q3_readmissions - s.Q1_readmissions)) AS lower_bound_readmissions,
       (s.Q3_readmissions + 1.5 * (s.Q3_readmissions - s.Q1_readmissions)) AS upper_bound_readmissions,
       CASE 
           WHEN r.number_of_readmissions < (s.Q1_readmissions - 1.5 * (s.Q3_readmissions - s.Q1_readmissions)) THEN 'Low Outlier'
           WHEN r.number_of_readmissions > (s.Q3_readmissions + 1.5 * (s.Q3_readmissions - s.Q1_readmissions)) THEN 'High Outlier'
           ELSE 'Normal'
       END AS outlier_status_readmissions

FROM readmissions_cleaned r
JOIN stats s ON r.measure_name = s.measure_name
)

-- REMOVE REPEAT AND UNECCESSARY COLUMNS FROM STATS_OUTLIERS WHICH WILL BE THE FINAL IQR TABLE FOR THE JOIN TO READMISSIONS
, stats_cleaned AS (
    SELECT  facility_id,
            measure_name,

            lower_bound_excess AS excess_lower_bound,
            upper_bound_excess AS excess_upper_bound,
            outlier_status_excess AS excess_outlier_status,

            lower_bound_expected AS expected_lower_bound,
            upper_bound_expected AS expected_upper_bound,
            outlier_status_expected AS expected_outlier_status,

            lower_bound_predicted AS predicted_lower_bound,
            upper_bound_predicted AS predicted_upper_bound,
            outlier_status_predicted AS predicted_outlier_status,

            lower_bound_discharges AS discharges_lower_bound,
            upper_bound_discharges AS discharges_upper_bound,
            outlier_status_discharges AS discharges_outlier_status,

            lower_bound_readmissions AS readmissions_lower_bound,
            upper_bound_readmissions AS readmissions_upper_bound,
            outlier_status_readmissions AS readmissions_outlier_status

    FROM stats_outiers)

-- Do the final merges for readmissions (Outlier Flagging: IQR and Z-Score, and Common names for measure names mapping)
SELECT  r.*,
        z.readmissions_outlier_z_score,
        s.excess_lower_bound,
        s.excess_upper_bound,
        s.excess_outlier_status,
        s.expected_lower_bound,
        s.expected_upper_bound,
        s.expected_outlier_status,
        s.predicted_lower_bound,
        s.predicted_upper_bound,
        s.predicted_outlier_status,
        s.discharges_lower_bound,
        s.discharges_upper_bound,
        s.discharges_outlier_status,
        s.readmissions_lower_bound,
        s.readmissions_upper_bound,
        s.readmissions_outlier_status,
        m.condition

FROM readmissions_cleaned r
LEFT JOIN z_score_outliers_cleaned z ON r.facility_id = z.facility_id AND r.measure_name = z.measure_name
LEFT JOIN stats_cleaned s ON r.facility_id = s.facility_id AND r.measure_name = s.measure_name
LEFT JOIN readmission_condition_mapping m on r.measure_name = m.measure_name
;

-- Export this final table as csv (readmissions_cleaned)
-- Create table readmissions_cleaned
CREATE TABLE readmissions_cleaned (
    facility_name VARCHAR (100),
    facility_id VARCHAR(10),
    state VARCHAR(5),
    measure_name VARCHAR(50),
    number_of_discharges VARCHAR(5), -- cast to int later, has ""
    excess_readmission_ratio VARCHAR(10), -- cast to decimal later
    predicted_readmission_rate VARCHAR(10), -- cast to decimal later
    expected_readmission_rate VARCHAR(10), -- cast to decimal later
    number_of_readmissions VARCHAR(5), -- cast to int later
    start_date DATE,
    end_date DATE,
    readmissions_outlier_z_score VARCHAR(50), --cast to decimal later
    excess_lower_bound VARCHAR(50), -- cast to decimal later
    excess_upper_bound VARCHAR(50), -- cast to decimal later
    excess_outlier_status VARCHAR(100),
    expected_lower_bound VARCHAR(50), -- cast to decimal later
    expected_upper_bound VARCHAR(50), -- cast to decimal later
    expected_outlier_status VARCHAR(50),
    predicted_lower_bound VARCHAR(50), -- cast to decimal later
    predicted_upper_bound VARCHAR(50), -- cast to decimal later
    predicted_outlier_status VARCHAR(50),
    discharges_lower_bound VARCHAR(50), -- cast to decimal later
    discharges_upper_bound VARCHAR(50), -- cast to decimal later
    discharges_outlier_status VARCHAR(50),
    readmissions_lower_bound VARCHAR(50), -- cast to decimal later
    readmissions_upper_bound VARCHAR(50), -- cast to decimal later
    readmissions_outlier_status VARCHAR(50),
    condition VARCHAR(100)
);

--number form table (does't work even if i show null '' in copy bracket)
CREATE TABLE readmissions_cleaned (
    facility_name VARCHAR (100),
    facility_id VARCHAR(10),
    state VARCHAR(5),
    measure_name VARCHAR(50),
    number_of_discharges INT, -- cast to int later, has ""
    excess_readmission_ratio DECIMAL, -- cast to decimal later
    predicted_readmission_rate DECIMAL, -- cast to decimal later
    expected_readmission_rate DECIMAL, -- cast to decimal later
    number_of_readmissions INT, -- cast to int later
    start_date DATE,
    end_date DATE,
    readmissions_outlier_z_score DECIMAL, --cast to decimal later
    excess_lower_bound DECIMAL, -- cast to decimal later
    excess_upper_bound DECIMAL, -- cast to decimal later
    excess_outlier_status VARCHAR(100),
    expected_lower_bound DECIMAL, -- cast to decimal later
    expected_upper_bound DECIMAL, -- cast to decimal later
    expected_outlier_status VARCHAR(50),
    predicted_lower_bound DECIMAL, -- cast to decimal later
    predicted_upper_bound DECIMAL, -- cast to decimal later
    predicted_outlier_status VARCHAR(50),
    discharges_lower_bound DECIMAL, -- cast to decimal later
    discharges_upper_bound DECIMAL, -- cast to decimal later
    discharges_outlier_status VARCHAR(50),
    readmissions_lower_bound DECIMAL, -- cast to decimal later
    readmissions_upper_bound DECIMAL, -- cast to decimal later
    readmissions_outlier_status VARCHAR(50),
    condition VARCHAR(100)
);

-- Load readmissions_cleaned table
COPY readmissions_cleaned
FROM 'C:\Desktop\Data Projects\Portfolio Projects\SQL&Tableau\Medicare\Medicare_Datasets\readmissions_cleaned.csv'
WITH (FORMAT csv, HEADER true);

--Check readmissions_cleaned table
SELECT *
FROM readmissions_cleaned;
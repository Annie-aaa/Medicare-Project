-- Load Readmissions Table
COPY readmissions (facility_name, facility_id , state, measure_name, number_of_discharges, footnote, excess_readmission_ratio,
    predicted_readmission_rate, expected_readmission_rate, number_of_readmissions, start_date, end_date)
FROM 'C:\Desktop\Data Projects\Portfolio Projects\SQL&Tableau\Medicare\Medicare_Datasets\FY_2025_Hospital_Readmissions_Reduction_Program_Hospital.csv'
WITH (FORMAT csv, HEADER true);

-- Load Costs Table
-- Had to use Python to change encoding to avoid loading erros
-- Cause leading zeros to disappear so add them back during cleanning
COPY costs (rndrng_prvdr_ccn, rndrng_prvdr_org_name, rndrng_prvdr_city, rndrng_prvdr_st, rndrng_prvdr_state_fips, rndrng_prvdr_zip5, rndrng_prvdr_state_abrvtn, 
    rndrng_prvdr_ruca, rndrng_prvdr_ruca_desc, drg_cd, drg_desc, total_dschrgs, avg_submtd_cvrd_chrg, avg_tot_pymt_amt, avg_mdcr_pymt_amt)
FROM 'C:\Desktop\Data Projects\Portfolio Projects\SQL&Tableau\Medicare\Medicare_Datasets\costs_correct_encoding_UTF8.csv'
WITH (FORMAT csv, HEADER true);

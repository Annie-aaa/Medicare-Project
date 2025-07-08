-- Hospital Readmissions Table
CREATE TABLE readmissions (
    facility_name VARCHAR(100),
    facility_id VARCHAR(10),
    state VARCHAR(5),
    measure_name VARCHAR(50),
    number_of_discharges VARCHAR(100),
    footnote INT,
    excess_readmission_ratio VARCHAR(100),
    predicted_readmission_rate VARCHAR(100),
    expected_readmission_rate VARCHAR(100),
    number_of_readmissions VARCHAR(100),
    start_date VARCHAR(30),
    end_date VARCHAR(30)
);

-- Costs Table
CREATE TABLE costs (
    rndrng_prvdr_ccn VARCHAR(10),
    rndrng_prvdr_org_name VARCHAR(100),
    rndrng_prvdr_city VARCHAR(100),
    rndrng_prvdr_st VARCHAR(50),
    rndrng_prvdr_state_fips VARCHAR(5),
    rndrng_prvdr_zip5 VARCHAR(5),
    rndrng_prvdr_state_abrvtn VARCHAR(5),
    rndrng_prvdr_ruca VARCHAR(20),
    rndrng_prvdr_ruca_desc VARCHAR(150),
    drg_cd VARCHAR(5),
    drg_desc VARCHAR(150),
    total_dschrgs INT,
    avg_submtd_cvrd_chrg VARCHAR(20),
    avg_tot_pymt_amt VARCHAR(20),
    avg_mdcr_pymt_amt VARCHAR(20)
);


CREATE TABLE readmission_condition_mapping (
    measure_name VARCHAR(50) PRIMARY KEY,
    condition VARCHAR(50)
);

INSERT INTO readmission_condition_mapping (measure_name, condition) VALUES
('READM-30-AMI-HRRP', 'Heart Attack (AMI)'),
('READM-30-HF-HRRP', 'Heart Failure (HF)'),
('READM-30-PN-HRRP', 'Pneumonia'),
('READM-30-COPD-HRRP', 'COPD'),
('READM-30-HIP-KNEE-HRRP', 'Hip/Knee Replacement (THA/TKA)'),
('READM-30-CABG-HRRP', 'CABG');

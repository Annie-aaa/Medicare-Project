CREATE TABLE drg_mapping (
    drg_code VARCHAR(5) PRIMARY KEY,  -- Store as VARCHAR to match costs table
    condition VARCHAR(50)
);

INSERT INTO drg_mapping (drg_code, condition) VALUES
('280', 'Heart Attack (AMI)'),
('281', 'Heart Attack (AMI)'),
('282', 'Heart Attack (AMI)'),
('291', 'Heart Failure (HF)'),
('292', 'Heart Failure (HF)'),
('293', 'Heart Failure (HF)'),
('193', 'Pneumonia'),
('194', 'Pneumonia'),
('195', 'Pneumonia'),
('190', 'COPD'),
('191', 'COPD'),
('192', 'COPD'),
('469', 'Hip/Knee Replacement (THA/TKA)'),
('470', 'Hip/Knee Replacement (THA/TKA)'),
('231', 'CABG'),
('232', 'CABG'),
('233', 'CABG'),
('234', 'CABG'),
('235', 'CABG'),
('236', 'CABG');


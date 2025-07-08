CREATE TABLE ruca_codes_map (
    ruca_code VARCHAR(5) PRIMARY KEY,  -- RUCA codes (1, 2, 3.1, etc.)
    ruca_short_description TEXT  -- Description of the RUCA category
);

-- Insert RUCA Code Mappings based on dataset
INSERT INTO ruca_codes_map (ruca_code, ruca_short_description) 
VALUES
    ('1.0', 'Urban core (metropolitan area)'),
    ('1.1', 'Principal city of a metropolitan area'),
    ('2.0', 'High commuting to urban core'),
    ('2.2', 'Moderate commuting to urban core'),
    ('3.0', 'Low commuting to urban core'),
    ('4.0', 'Micropolitan core (small urban centers)'),
    ('4.1', 'Principal city of a micropolitan area'),
    ('5.0', 'High commuting to a micropolitan core'),
    ('6.0', 'Low commuting to a micropolitan core'),
    ('7.0', 'Small town core'),
    ('7.1', 'High commuting to a small town'),
    ('7.2', 'Moderate commuting to a small town'),
    ('8.0', 'Low commuting to a small town'),
    ('9.0', 'Isolated rural area'),
    ('10.0', 'Remote rural area'),
    ('10.2', 'Rural area with moderate commuting to a small town'),
    ('99.0', 'Unknown / Not Coded');  -- Special case for missing data


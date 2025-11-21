-- 0. Use your DB
CREATE DATABASE IF NOT EXISTS loan_project;
USE loan_project;

-- 1. Create table 

CREATE TABLE loan_data (
  LoanID VARCHAR(100) PRIMARY KEY,
  Age INT,
  Income DECIMAL(15,2),
  LoanAmount DECIMAL(15,2),
  CreditScore INT,
  MonthsEmployed INT,
  NumCreditLines INT,
  InterestRate DECIMAL(6,2),
  LoanTerm INT,
  DTIRatio DECIMAL(6,2),
  Education VARCHAR(100),
  EmploymentType VARCHAR(100),
  MaritalStatus VARCHAR(50),
  HasMortgage VARCHAR(10),
  HasDependents VARCHAR(10),
  LoanPurpose VARCHAR(200),
  HasCoSigner VARCHAR(10),
  `Default` VARCHAR(10)
) ;

USE loan_project;
SELECT COUNT(*) AS rows_loaded FROM loan_data;
SELECT * FROM LOAN_DATA;

-- 3. Standardize text fields (lowercase + trim)
UPDATE loan_data
SET `Default` = LOWER(TRIM(`Default`)),
    HasMortgage = LOWER(TRIM(HasMortgage)),
    HasCoSigner = LOWER(TRIM(HasCoSigner)),
    HasDependents = LOWER(TRIM(HasDependents)),
    EmploymentType = TRIM(EmploymentType),
    Education = TRIM(Education),
    MaritalStatus = TRIM(MaritalStatus),
    LoanPurpose = TRIM(LoanPurpose);

SET AUTOCOMMIT=0;
SET SQL_SAFE_UPDATES=0;
SELECT * FROM LOAN_DATA;

-- 4. Remove obviously invalid rows
DELETE FROM loan_data WHERE Income IS NULL OR LoanAmount IS NULL OR Income <= 0 OR LoanAmount <= 0 OR Age IS NULL OR Age < 18;
----------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 5. Remove duplicate LoanIDs if any (keep first)
ALTER TABLE loan_data ADD COLUMN tmp_id INT AUTO_INCREMENT UNIQUE;

DELETE ld1 FROM loan_data ld1
JOIN loan_data ld2
  ON ld1.LoanID = ld2.LoanID AND ld1.tmp_id > ld2.tmp_id;
  
ALTER TABLE loan_data DROP COLUMN TMP_ID;
---------------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT * FROM LOAN_DATA;

-- 6. Add derived binary flag and buckets

ALTER TABLE loan_data
  ADD COLUMN IsDefault TINYINT(1) DEFAULT 0,
  ADD COLUMN IncomeBucket VARCHAR(30),
  ADD COLUMN LoanBucket VARCHAR(30),
  ADD COLUMN CreditCategory VARCHAR(30),
  ADD COLUMN AgeBucket VARCHAR(30),
  ADD COLUMN DTI_Bucket VARCHAR(30);
  
  
  UPDATE loan_data
SET IsDefault = CASE WHEN `Default` = 1 THEN 1 ELSE 0 END;



SELECT MIN(Income), MAX(Income) FROM loan_data;
UPDATE loan_data
SET IncomeBucket =
  CASE
    WHEN Income < 20000 THEN '<20k'
    WHEN Income >= 20000 AND Income < 40000 THEN '20k-40k'
    WHEN Income >= 40000 AND Income < 80000 THEN '40k-80k'
    WHEN Income >= 80000 AND Income < 120000 THEN '80k-120k'
    ELSE '120k+'
  END;


SELECT IncomeBucket, COUNT(*) AS INCOME
FROM loan_data
GROUP BY IncomeBucket
ORDER BY IncomeBucket;

-- LOANBUCKET

SELECT MIN(LoanAmount) AS MinLoan,
       MAX(LoanAmount) AS MaxLoan
FROM loan_data;

UPDATE loan_data
SET LoanBucket =
  CASE
    WHEN LoanAmount < 10000 THEN '<10k'
    WHEN LoanAmount >= 10000 AND LoanAmount < 50000 THEN '10k-50k'
    WHEN LoanAmount >= 50000 AND LoanAmount < 100000 THEN '50k-100k'
    WHEN LoanAmount >= 100000 AND LoanAmount < 150000 THEN '100k-150k'
    ELSE '150k+'
  END;

SELECT LoanBucket, COUNT(*) AS CountRows
FROM loan_data
GROUP BY LoanBucket
ORDER BY LoanBucket;


-- CHEACK CREDIT SCORE RANGE 

SELECT MIN(CreditScore) AS MinScore,
       MAX(CreditScore) AS MaxScore,
       COUNT(*) AS TotalRows
FROM loan_data;

UPDATE loan_data
SET CreditCategory =
  CASE
    WHEN CreditScore >= 750 THEN 'Excellent'
    WHEN CreditScore >= 650 THEN 'Good'
    WHEN CreditScore >= 550 THEN 'Fair'
    ELSE 'Poor'
  END;

SELECT
  CreditCategory,
  MIN(CreditScore) AS MinScore,
  MAX(CreditScore) AS MaxScore,
  COUNT(*)         AS CountRows
FROM loan_data
GROUP BY CreditCategory
ORDER BY MinScore;

-- AGE GROUP BUCKET 

UPDATE loan_data
SET AgeBucket =
  CASE
    WHEN Age < 25 THEN '<25'
    WHEN Age >= 25 AND Age <= 34 THEN '25-34'
    WHEN Age >= 35 AND Age <= 44 THEN '35-44'
    WHEN Age >= 45 AND Age <= 54 THEN '45-54'
    ELSE '55+'
  END;
  
  SELECT AgeBucket,
       MIN(Age)  AS MinAge,
       MAX(Age)  AS MaxAge,
       COUNT(*)  AS CountRows
FROM loan_data
GROUP BY AgeBucket
ORDER BY MinAge;

SELECT * FROM LOAN_DATA;
-- DTI RANGE %

 SELECT  MIN(DTIRatio) AS MinDTI,
       MAX(DTIRatio) AS MaxDTI,
       COUNT(*)      AS CountRows
FROM loan_data;

UPDATE loan_data
SET DTI_Bucket =
  CASE
    WHEN DTIRatio < 0.20 THEN '<20%'
    WHEN DTIRatio >= 0.20 AND DTIRatio <= 0.35 THEN '20-35%'
    ELSE '>35%'
  END;
  
  SELECT DTI_Bucket,
       MIN(DTIRatio) AS MinDTI,
       MAX(DTIRatio) AS MaxDTI,
       COUNT(*)      AS CountRows
FROM loan_data
GROUP BY DTI_Bucket
ORDER BY MinDTI;


 -- 7. Create indexes to speed queries
 
 
CREATE INDEX idx_income ON loan_data(Income);
CREATE INDEX idx_loanamount ON loan_data(LoanAmount);
CREATE INDEX idx_credit ON loan_data(CreditScore);
CREATE INDEX idx_incomebucket ON loan_data(IncomeBucket);
CREATE INDEX idx_loanbucket ON loan_data(LoanBucket);


 -- Create convenient views for Power BI (pre-aggregated)
		-- OVERALL KPIS
        
CREATE OR REPLACE VIEW v_overall_kpis AS
SELECT
  COUNT(*) AS total_loans,
  SUM(IsDefault) AS total_defaults,
  ROUND(100.0 * SUM(IsDefault) / COUNT(*), 2) AS default_rate_pct,
  ROUND(AVG(LoanAmount), 2) AS avg_loan_amount,
  ROUND(AVG(Income), 2) AS avg_income
FROM loan_data;

		-- DEFAULT BY INCOME
        
CREATE OR REPLACE VIEW v_default_by_income AS
SELECT
  IncomeBucket,
  COUNT(*) AS applications,
  SUM(IsDefault) AS defaults,
  ROUND(100.0 * SUM(IsDefault) / COUNT(*), 2) AS default_rate
FROM loan_data
GROUP BY IncomeBucket;

		-- DEFAULT BY LOANBUCKET
        
CREATE OR REPLACE VIEW v_default_by_loanbucket AS
SELECT
  LoanBucket,
  COUNT(*) AS total_loans,
  SUM(IsDefault) AS defaults,
  ROUND(100.0 * SUM(IsDefault) / COUNT(*), 2) AS default_rate
FROM loan_data
GROUP BY LoanBucket;

		-- DEFAOULT BY CATEGORY 
        
CREATE OR REPLACE VIEW v_default_by_credit AS
SELECT
  CreditCategory,
  COUNT(*) AS applicants,
  ROUND(100.0 * SUM(IsDefault) / COUNT(*), 2) AS default_rate
FROM loan_data
GROUP BY CreditCategory;

SELECT * FROM v_overall_kpis;
SELECT * FROM v_default_by_income;
SELECT * FROM v_default_by_loanbucket;
SELECT * FROM v_default_by_credit;

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- “Credit Risk Scoring Model Using Financial Indicators”

	ALTER TABLE loan_data
	ADD COLUMN RiskScore INT;
    
		UPDATE loan_data
		SET RiskScore =
		  ( 
			(CASE 
				WHEN Income < 20000 THEN 30
				WHEN Income BETWEEN 20000 AND 50000 THEN 20
				ELSE 10 
			 END)
			+
			(CASE 
				WHEN CreditScore < 550 THEN 40
				WHEN CreditScore BETWEEN 550 AND 650 THEN 25 
				ELSE 10 
			 END)
			+
			(CASE 
				WHEN DTIRatio > 0.35 THEN 30
				WHEN DTIRatio BETWEEN 0.20 AND 0.35 THEN 20
				ELSE 10 
			 END)
			+
			(CASE 
				WHEN LoanAmount > 30000 THEN 25 
				ELSE 10 
			 END)
		  );


SELECT RiskScore, COUNT(*) AS cnt
FROM loan_data
GROUP BY RiskScore
ORDER BY RiskScore;

-- TO SEE RISK CATEGORY 
	
    ALTER TABLE loan_data
	ADD COLUMN RiskCategory VARCHAR(20);
    
    UPDATE loan_data
SET RiskCategory =
  CASE
    WHEN RiskScore >= 90 THEN 'High Risk'
    WHEN RiskScore BETWEEN 60 AND 89 THEN 'Medium Risk'
    ELSE 'Low Risk'
  END;

SELECT RiskCategory, COUNT(*) AS customers
FROM loan_data
GROUP BY RiskCategory;


---------------------------------------------------------------------------------------------------------------------------------------------------------------
-- ADVANCED SEGMENTATION (Multi-factor analysis)
  
	SELECT 
		IncomeBucket,
		CreditCategory,
		LoanBucket,
		COUNT(*) AS Applications,
		ROUND(100 * SUM(IsDefault) / COUNT(*), 2) AS DefaultRate
	FROM loan_data
	GROUP BY 
		IncomeBucket,
		CreditCategory,
		LoanBucket
	HAVING COUNT(*) >= 100
	ORDER BY DefaultRate DESC;
    
    -- CREATE VIEW RSIK SUMMARY
    
CREATE OR REPLACE VIEW v_risk_summary AS
SELECT 
			IncomeBucket, 
			CreditCategory, 
			LoanBucket,
			COUNT(*) AS Applicants,
			SUM(IsDefault) AS Defaults,
			ROUND(100 * SUM(IsDefault) / COUNT(*), 2) AS DefaultRate
	FROM loan_data
	GROUP BY 
		IncomeBucket, 
		CreditCategory, 
		LoanBucket;


SELECT *
FROM v_risk_summary
ORDER BY DefaultRate DESC;

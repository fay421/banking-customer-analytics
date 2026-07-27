/*==============================================================
  BANK CUSTOMER ANALYTICS PROJECT
  PHASES 1–8
==============================================================*/

USE bank_transaction;


/*==============================================================
  PHASE 1: IMPORT VERIFICATION
  Verify tables, structures, and row counts
==============================================================*/

SHOW TABLES;

DESCRIBE transaction_data;
DESCRIBE customer_data;
DESCRIBE bank_data;


-- Verify imported row counts
SELECT 'transaction_data' AS table_name, COUNT(*) AS row_count
FROM transaction_data

UNION ALL

SELECT 'customer_data', COUNT(*)
FROM customer_data

UNION ALL

SELECT 'bank_data', COUNT(*)
FROM bank_data;


/*==============================================================
  PHASE 2: DATA MODELING AND RELATIONSHIP VALIDATION
==============================================================*/

-- Check uniqueness of transaction primary key
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT Transaction_ID) AS unique_transaction_ids
FROM transaction_data;


-- Check uniqueness of customer primary key
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT Customer_ID) AS unique_customer_ids
FROM customer_data;


-- Check uniqueness of branch primary key
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT Branch_ID) AS unique_branch_ids
FROM bank_data;


-- Check transaction-to-customer relationship
SELECT
    COUNT(*) AS unmatched_transactions
FROM transaction_data AS t
LEFT JOIN customer_data AS c
    ON t.Customer_ID = c.Customer_ID
WHERE c.Customer_ID IS NULL;


-- Check customer-to-branch relationship
SELECT
    COUNT(*) AS unmatched_customers
FROM customer_data AS c
LEFT JOIN bank_data AS b
    ON c.Branch_ID = b.Branch_ID
WHERE c.Branch_ID IS NOT NULL
  AND b.Branch_ID IS NULL;


/*==============================================================
  PHASE 3: ANALYTICAL VIEW
==============================================================*/

DROP VIEW IF EXISTS vw_transaction_analysis;


CREATE VIEW vw_transaction_analysis AS
SELECT
    /* Transaction fact data */
    t.Transaction_ID,
    t.Customer_ID,
    t.Account_Type,
    t.Total_Balance,
    t.Transaction_Amount,
    t.Investment_Amount,
    t.Investment_Type,

    STR_TO_DATE(
        NULLIF(TRIM(t.Transaction_Date), ''),
        '%m/%d/%Y'
    ) AS Transaction_Date,

    /* Customer dimension data */
    CASE
        WHEN TRIM(c.Age) REGEXP '^[0-9]+$'
        THEN CAST(TRIM(c.Age) AS UNSIGNED)
        ELSE NULL
    END AS Age,

    c.Customer_Type,
    c.City,
    c.Region,
    c.Bank_Name,
    c.Branch_ID,

    /* Bank dimension data */
    b.Firm_Revenue,
    b.Expenses,
    b.Profit_Margin

FROM transaction_data AS t

LEFT JOIN customer_data AS c
    ON t.Customer_ID = c.Customer_ID

LEFT JOIN bank_data AS b
    ON c.Branch_ID = b.Branch_ID;


-- Verify analytical view
SELECT *
FROM vw_transaction_analysis
LIMIT 10;


/*==============================================================
  PHASE 4: DATA TYPE VALIDATION
==============================================================*/

-- Validate converted ages
SELECT
    MIN(Age) AS minimum_age,  -- 18
    ROUND(AVG(Age), 2) AS average_age,-- 49.09
    MAX(Age) AS maximum_age  -- 79
FROM vw_transaction_analysis;


-- Validate converted transaction dates
SELECT
    MIN(Transaction_Date) AS earliest_transaction_date,  -- 2022-03-21
    MAX(Transaction_Date) AS latest_transaction_date     -- 2025-03-20
FROM vw_transaction_analysis;


-- Find dates that could not be converted
SELECT
    Transaction_ID,
    Transaction_Date
FROM transaction_data
WHERE Transaction_Date IS NOT NULL
  AND TRIM(Transaction_Date) <> ''
  AND STR_TO_DATE(TRIM(Transaction_Date), '%m/%d/%Y') IS NULL;


/*==============================================================
  PHASE 5: DATA PROFILING
==============================================================*/

-- NULL-value profile for the analytical view
SELECT
    COUNT(*) AS total_rows, -- 10000

    SUM(Transaction_ID IS NULL) AS transaction_id_nulls,
    SUM(Customer_ID IS NULL) AS customer_id_nulls,
    SUM(Account_Type IS NULL) AS account_type_nulls,
    SUM(Total_Balance IS NULL) AS total_balance_nulls,
    SUM(Transaction_Amount IS NULL) AS transaction_amount_nulls,
    SUM(Investment_Amount IS NULL) AS investment_amount_nulls,
    SUM(Investment_Type IS NULL) AS investment_type_nulls,
    SUM(Transaction_Date IS NULL) AS transaction_date_nulls,

    SUM(Age IS NULL) AS age_nulls, -- 501
    SUM(Customer_Type IS NULL) AS customer_type_nulls, -- 980
    SUM(City IS NULL) AS city_nulls, -- 504
    SUM(Region IS NULL) AS region_nulls, 
    SUM(Bank_Name IS NULL) AS bank_name_nulls,
    SUM(Branch_ID IS NULL) AS branch_id_nulls,

    SUM(Firm_Revenue IS NULL) AS firm_revenue_nulls, -- 567
    SUM(Expenses IS NULL) AS expenses_nulls, -- 567
    SUM(Profit_Margin IS NULL) AS profit_margin_nulls -- 567

FROM vw_transaction_analysis;


-- Blank-value profile for customer data
SELECT
    SUM(TRIM(Age) = '') AS age_blanks,
    SUM(TRIM(Customer_Type) = '') AS customer_type_blanks,
    SUM(TRIM(City) = '') AS city_blanks,
    SUM(TRIM(Region) = '') AS region_blanks,
    SUM(TRIM(Bank_Name) = '') AS bank_name_blanks,
    SUM(TRIM(Branch_ID) = '') AS branch_id_blanks
FROM customer_data; -- 0 for all


/*==============================================================
  PHASE 6: RELATIONSHIP AND MISSING-VALUE INVESTIGATION
==============================================================*/

-- Missing Branch_ID values in customer data
SELECT
    COUNT(*) AS customers_without_branch_id
FROM customer_data
WHERE Branch_ID IS NULL
   OR TRIM(Branch_ID) = ''; -- 0


-- Branch IDs appearing in customer_data but not bank_data
SELECT DISTINCT
    c.Branch_ID
FROM customer_data AS c
LEFT JOIN bank_data AS b
    ON c.Branch_ID = b.Branch_ID
WHERE c.Branch_ID IS NOT NULL
  AND TRIM(c.Branch_ID) <> ''
  AND b.Branch_ID IS NULL
ORDER BY c.Branch_ID;


-- Number of customers affected by unmatched Branch_ID values
SELECT
    COUNT(*) AS affected_customers
FROM customer_data AS c
LEFT JOIN bank_data AS b
    ON c.Branch_ID = b.Branch_ID
WHERE c.Branch_ID IS NOT NULL
  AND TRIM(c.Branch_ID) <> ''
  AND b.Branch_ID IS NULL; -- 516


-- Number of distinct customers affected
SELECT
    COUNT(DISTINCT c.Customer_ID) AS affected_distinct_customers
FROM customer_data AS c
LEFT JOIN bank_data AS b
    ON c.Branch_ID = b.Branch_ID
WHERE c.Branch_ID IS NOT NULL
  AND TRIM(c.Branch_ID) <> ''
  AND b.Branch_ID IS NULL; -- 516


-- Number of transactions affected by unmatched Branch_ID values
SELECT
    COUNT(*) AS affected_transactions
FROM transaction_data AS t
JOIN customer_data AS c
    ON t.Customer_ID = c.Customer_ID
LEFT JOIN bank_data AS b
    ON c.Branch_ID = b.Branch_ID
WHERE c.Branch_ID IS NOT NULL
  AND TRIM(c.Branch_ID) <> ''
  AND b.Branch_ID IS NULL; -- 567


-- Confirm the reason financial values are missing
SELECT
    COUNT(*) AS rows_with_missing_bank_financials
FROM vw_transaction_analysis
WHERE Firm_Revenue IS NULL
   OR Expenses IS NULL
   OR Profit_Margin IS NULL; -- 567


/*==============================================================
  PHASE 7: DATA QUALITY VALIDATION
==============================================================*/


/*--------------------------------------------------------------
  7.1 Standardize blank values as NULL
--------------------------------------------------------------*/

UPDATE customer_data
SET Age = NULLIF(TRIM(Age), '');


UPDATE customer_data
SET Customer_Type = NULLIF(TRIM(Customer_Type), '');


UPDATE customer_data
SET City = NULLIF(TRIM(City), '');


UPDATE customer_data
SET Region = NULLIF(TRIM(Region), '');


UPDATE customer_data
SET Bank_Name = NULLIF(TRIM(Bank_Name), '');


UPDATE customer_data
SET Branch_ID = NULLIF(TRIM(Branch_ID), '');


UPDATE transaction_data
SET Account_Type = NULLIF(TRIM(Account_Type), '');


UPDATE transaction_data
SET Investment_Type = NULLIF(TRIM(Investment_Type), '');


UPDATE transaction_data
SET Transaction_Date = NULLIF(TRIM(Transaction_Date), '');


/*--------------------------------------------------------------
  7.2 Duplicate validation
--------------------------------------------------------------*/

-- Duplicate Transaction_ID values
SELECT
    Transaction_ID,
    COUNT(*) AS duplicate_count
FROM transaction_data
GROUP BY Transaction_ID
HAVING COUNT(*) > 1;


-- Duplicate Customer_ID values
SELECT
    Customer_ID,
    COUNT(*) AS duplicate_count
FROM customer_data
GROUP BY Customer_ID
HAVING COUNT(*) > 1;


-- Duplicate Branch_ID values
SELECT
    Branch_ID,
    COUNT(*) AS duplicate_count
FROM bank_data
GROUP BY Branch_ID
HAVING COUNT(*) > 1;


/*--------------------------------------------------------------
  7.3 Impossible-value validation
--------------------------------------------------------------*/

-- Invalid ages
SELECT
    Customer_ID,
    Age
FROM customer_data
WHERE TRIM(Age) REGEXP '^[0-9]+$'
  AND CAST(TRIM(Age) AS UNSIGNED) NOT BETWEEN 18 AND 120;


-- Non-numeric age values
SELECT
    Customer_ID,
    Age
FROM customer_data
WHERE Age IS NOT NULL
  AND TRIM(Age) <> ''
  AND TRIM(Age) NOT REGEXP '^[0-9]+$';


-- Negative transaction amounts
SELECT *
FROM transaction_data
WHERE Transaction_Amount < 0;


-- Negative balances
SELECT *
FROM transaction_data
WHERE Total_Balance < 0;


-- Negative investment amounts
SELECT *
FROM transaction_data
WHERE Investment_Amount < 0;


-- Future transaction dates
SELECT *
FROM vw_transaction_analysis
WHERE Transaction_Date > CURDATE();


-- Impossible bank financial values
SELECT *
FROM bank_data
WHERE Firm_Revenue < 0
   OR Expenses < 0;


/*--------------------------------------------------------------
  7.4 Category consistency validation
--------------------------------------------------------------*/

SELECT DISTINCT Customer_Type
FROM customer_data
ORDER BY Customer_Type;


SELECT DISTINCT City
FROM customer_data
ORDER BY City;


SELECT DISTINCT Region
FROM customer_data
ORDER BY Region;


SELECT DISTINCT Bank_Name
FROM customer_data
ORDER BY Bank_Name;


SELECT DISTINCT Account_Type
FROM transaction_data
ORDER BY Account_Type;


SELECT DISTINCT Investment_Type
FROM transaction_data
ORDER BY Investment_Type;


/*==============================================================
  PHASE 8: EXPLORATORY DATA ANALYSIS
==============================================================*/


/*--------------------------------------------------------------
  8.1 Dataset overview
--------------------------------------------------------------*/

SELECT
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT Transaction_ID) AS unique_transactions,-- 10000
    COUNT(DISTINCT Customer_ID) AS unique_customers, -- 6335
    COUNT(DISTINCT Branch_ID) AS unique_branches,-- 997
    MIN(Transaction_Date) AS earliest_transaction_date, -- 2022-03-21
    MAX(Transaction_Date) AS latest_transaction_date -- 2025-03-20
FROM vw_transaction_analysis;


/*--------------------------------------------------------------
  8.2 Numerical summary
--------------------------------------------------------------*/

SELECT
    MIN(Age) AS minimum_age,-- 18
    ROUND(AVG(Age), 2) AS average_age, -- 49.09
    MAX(Age) AS maximum_age, -- 79

    ROUND(MIN(Total_Balance), 2) AS minimum_balance, -- 1003
    ROUND(AVG(Total_Balance), 2) AS average_balance,-- 50221.51
    ROUND(MAX(Total_Balance), 2) AS maximum_balance, -- 99993

    ROUND(MIN(Transaction_Amount), 2) AS minimum_transaction, -- 52 
    ROUND(AVG(Transaction_Amount), 2) AS average_transaction, -- 2542.71
    ROUND(MAX(Transaction_Amount), 2) AS maximum_transaction, -- 7046

    ROUND(MIN(Investment_Amount), 2) AS minimum_investment, -- 1001
    ROUND(AVG(Investment_Amount), 2) AS average_investment, -- 25550.25
    ROUND(MAX(Investment_Amount), 2) AS maximum_investment -- 49998

FROM vw_transaction_analysis;


/*--------------------------------------------------------------
  8.3 Account analysis
--------------------------------------------------------------*/

SELECT
    COALESCE(Account_Type, 'Unknown') AS account_type,
    COUNT(*) AS transaction_count,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage
FROM vw_transaction_analysis
GROUP BY COALESCE(Account_Type, 'Unknown')
ORDER BY transaction_count DESC;


/*--------------------------------------------------------------
  8.4 Investment analysis
--------------------------------------------------------------*/

SELECT
    COALESCE(Investment_Type, 'Unknown') AS investment_type,
    COUNT(*) AS transaction_count,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage,
    ROUND(AVG(Investment_Amount), 2) AS average_investment,
    ROUND(SUM(Investment_Amount), 2) AS total_investment
FROM vw_transaction_analysis
GROUP BY COALESCE(Investment_Type, 'Unknown')
ORDER BY transaction_count DESC;


/*--------------------------------------------------------------
  8.5 Customer-type distribution
--------------------------------------------------------------*/

SELECT
    COALESCE(Customer_Type, 'Unknown') AS customer_type,
    COUNT(DISTINCT Customer_ID) AS customer_count,
    ROUND(
        COUNT(DISTINCT Customer_ID) * 100.0
        / SUM(COUNT(DISTINCT Customer_ID)) OVER (),
        2
    ) AS percentage
FROM vw_transaction_analysis
GROUP BY COALESCE(Customer_Type, 'Unknown')
ORDER BY customer_count DESC;


/*--------------------------------------------------------------
  8.6 City distribution
--------------------------------------------------------------*/

SELECT
    COALESCE(City, 'Unknown') AS city,
    COUNT(DISTINCT Customer_ID) AS customer_count,
    COUNT(*) AS transaction_count,
    ROUND(SUM(Transaction_Amount), 2) AS total_transaction_amount
FROM vw_transaction_analysis
GROUP BY COALESCE(City, 'Unknown')
ORDER BY transaction_count DESC;


/*--------------------------------------------------------------
  8.7 Regional analysis
--------------------------------------------------------------*/

SELECT
    COALESCE(Region, 'Unknown') AS region,
    COUNT(DISTINCT Customer_ID) AS customer_count,
    COUNT(*) AS transaction_count,
    ROUND(SUM(Transaction_Amount), 2) AS total_transaction_amount,
    ROUND(AVG(Transaction_Amount), 2) AS average_transaction_amount,
    ROUND(SUM(Investment_Amount), 2) AS total_investment_amount,
    ROUND(AVG(Total_Balance), 2) AS average_balance
FROM vw_transaction_analysis
GROUP BY COALESCE(Region, 'Unknown')
ORDER BY total_transaction_amount DESC;


/*--------------------------------------------------------------
  8.8 Customer age groups

  DISTINCT is used first because one customer may have multiple
  transactions and should only be counted once.
--------------------------------------------------------------*/

WITH customers AS
(
    SELECT DISTINCT
        Customer_ID,
        Age
    FROM vw_transaction_analysis
)

SELECT
    CASE
        WHEN Age < 25 THEN 'Under 25'
        WHEN Age BETWEEN 25 AND 34 THEN '25-34'
        WHEN Age BETWEEN 35 AND 44 THEN '35-44'
        WHEN Age BETWEEN 45 AND 54 THEN '45-54'
        WHEN Age >= 55 THEN '55+'
        ELSE 'Unknown'
    END AS age_group,

    COUNT(*) AS customer_count,

    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage

FROM customers

GROUP BY
    CASE
        WHEN Age < 25 THEN 'Under 25'
        WHEN Age BETWEEN 25 AND 34 THEN '25-34'
        WHEN Age BETWEEN 35 AND 44 THEN '35-44'
        WHEN Age BETWEEN 45 AND 54 THEN '45-54'
        WHEN Age >= 55 THEN '55+'
        ELSE 'Unknown'
    END

ORDER BY
    CASE age_group
        WHEN 'Under 25' THEN 1
        WHEN '25-34' THEN 2
        WHEN '35-44' THEN 3
        WHEN '45-54' THEN 4
        WHEN '55+' THEN 5
        ELSE 6
    END;


/*--------------------------------------------------------------
  8.9 Balance segmentation

  CASE stops after the first true condition, so balances are not
  counted in multiple bands.
--------------------------------------------------------------*/

SELECT
    CASE
        WHEN Total_Balance IS NULL THEN 'Unknown'
        WHEN Total_Balance < 10000 THEN 'Under 10K'
        WHEN Total_Balance < 50000 THEN '10K-49K'
        WHEN Total_Balance < 100000 THEN '50K-99K'
        WHEN Total_Balance < 250000 THEN '100K-249K'
        ELSE '250K+'
    END AS balance_band,

    COUNT(*) AS transaction_count,
    COUNT(DISTINCT Customer_ID) AS customer_count,
    ROUND(AVG(Total_Balance), 2) AS average_balance

FROM vw_transaction_analysis

GROUP BY
    CASE
        WHEN Total_Balance IS NULL THEN 'Unknown'
        WHEN Total_Balance < 10000 THEN 'Under 10K'
        WHEN Total_Balance < 50000 THEN '10K-49K'
        WHEN Total_Balance < 100000 THEN '50K-99K'
        WHEN Total_Balance < 250000 THEN '100K-249K'
        ELSE '250K+'
    END

ORDER BY
    CASE balance_band
        WHEN 'Under 10K' THEN 1
        WHEN '10K-49K' THEN 2
        WHEN '50K-99K' THEN 3
        WHEN '100K-249K' THEN 4
        WHEN '250K+' THEN 5
        ELSE 6
    END;


/*--------------------------------------------------------------
  8.10 Top transactions
--------------------------------------------------------------*/

SELECT
    Transaction_ID,
    Customer_ID,
    Account_Type,
    Transaction_Date,
    Total_Balance,
    Transaction_Amount,
    Investment_Amount
FROM vw_transaction_analysis
ORDER BY Transaction_Amount DESC
LIMIT 20;


/*--------------------------------------------------------------
  8.11 Top customers by total transaction activity
--------------------------------------------------------------*/

SELECT
    Customer_ID,
    COUNT(*) AS transaction_count,
    ROUND(SUM(Transaction_Amount), 2) AS total_transaction_amount,
    ROUND(AVG(Transaction_Amount), 2) AS average_transaction_amount,
    ROUND(MAX(Total_Balance), 2) AS latest_or_maximum_balance,
    ROUND(SUM(Investment_Amount), 2) AS total_investment_amount
FROM vw_transaction_analysis
GROUP BY Customer_ID
ORDER BY total_transaction_amount DESC
LIMIT 20;


/*--------------------------------------------------------------
  8.12 Branch performance
--------------------------------------------------------------*/

SELECT
    Branch_ID,
    COALESCE(City, 'Unknown') AS city,
    COALESCE(Region, 'Unknown') AS region,
    COUNT(DISTINCT Customer_ID) AS customer_count,
    COUNT(*) AS transaction_count,
    ROUND(SUM(Transaction_Amount), 2) AS total_transaction_amount,
    ROUND(AVG(Transaction_Amount), 2) AS average_transaction_amount,
    ROUND(MAX(Firm_Revenue), 2) AS firm_revenue,
    ROUND(MAX(Expenses), 2) AS expenses,
    ROUND(MAX(Profit_Margin), 2) AS profit_margin
FROM vw_transaction_analysis
WHERE Branch_ID IS NOT NULL
GROUP BY
    Branch_ID,
    COALESCE(City, 'Unknown'),
    COALESCE(Region, 'Unknown')
ORDER BY total_transaction_amount DESC;


/*--------------------------------------------------------------
  8.13 Revenue and profitability summary

  MAX is used because branch-level financial values repeat for
  every transaction belonging to the same branch.
--------------------------------------------------------------*/

WITH branch_financials AS
(
    SELECT
        Branch_ID,
        MAX(Firm_Revenue) AS Firm_Revenue,
        MAX(Expenses) AS Expenses,
        MAX(Profit_Margin) AS Profit_Margin
    FROM vw_transaction_analysis
    WHERE Branch_ID IS NOT NULL
    GROUP BY Branch_ID
)

SELECT
    COUNT(*) AS matched_branches,
    ROUND(SUM(Firm_Revenue), 2) AS total_firm_revenue,
    ROUND(SUM(Expenses), 2) AS total_expenses,
    ROUND(AVG(Profit_Margin), 2) AS average_profit_margin
FROM branch_financials;


/*--------------------------------------------------------------
  8.14 Monthly transaction trend
--------------------------------------------------------------*/

SELECT
    DATE_FORMAT(Transaction_Date, '%Y-%m') AS transaction_month,
    COUNT(*) AS transaction_count,
    ROUND(SUM(Transaction_Amount), 2) AS total_transaction_amount,
    ROUND(AVG(Transaction_Amount), 2) AS average_transaction_amount,
    ROUND(SUM(Investment_Amount), 2) AS total_investment_amount
FROM vw_transaction_analysis
WHERE Transaction_Date IS NOT NULL
GROUP BY DATE_FORMAT(Transaction_Date, '%Y-%m')
ORDER BY transaction_month;


/*--------------------------------------------------------------
  8.15 Outlier Detection (IQR Method)
  Detect unusually large or small transaction amounts
--------------------------------------------------------------*/

WITH ranked AS (
    SELECT
        Transaction_ID,
        Customer_ID,
        Transaction_Amount,
        NTILE(4) OVER (ORDER BY Transaction_Amount) AS quartile
    FROM vw_transaction_analysis
),

quartiles AS (
    SELECT
        MAX(CASE WHEN quartile = 1 THEN Transaction_Amount END) AS Q1,
        MAX(CASE WHEN quartile = 3 THEN Transaction_Amount END) AS Q3
    FROM ranked
),

bounds AS (
    SELECT
        Q1,
        Q3,
        (Q3 - Q1) AS IQR,
        Q1 - 1.5 * (Q3 - Q1) AS lower_bound,
        Q3 + 1.5 * (Q3 - Q1) AS upper_bound
    FROM quartiles

)
SELECT * FROM bounds;
SELECT
    r.Transaction_ID,
    r.Customer_ID,
    r.Transaction_Amount,
    b.lower_bound,
    b.upper_bound
FROM ranked r
CROSS JOIN bounds b
WHERE r.Transaction_Amount < b.lower_bound
   OR r.Transaction_Amount > b.upper_bound
ORDER BY r.Transaction_Amount DESC; -- no outliers
/*==============================================================
  PHASE 9: CUSTOMER ANALYTICS & BUSINESS INSIGHTS

  Objective:
  Transform transactional data into business intelligence by:

  • Building executive KPIs
  • Scoring customer value
  • Segmenting customers
  • Evaluating branch performance
==============================================================*/

/*==============================================================
  9.1 EXECUTIVE KPIs
  High-level business metrics for executive reporting.
==============================================================*/
SELECT
	COUNT(DISTINCT Customer_ID ) as Total_Customers
FROM vw_transaction_analysis; -- 6335

-- Total Transactions
SELECT
	COUNT(DISTINCT Transaction_ID ) as Total_Transaction
FROM vw_transaction_analysis; -- 10000

-- Total Transaction Amount
SELECT 
	SUM(Transaction_Amount) as Total_Transaction_Amount
FROM vw_transaction_analysis; -- '25,427,074'

-- Total Investment Amount
SELECT 
	SUM(Investment_Amount) as Total_Invetment_Amount
FROM vw_transaction_analysis; -- '255,502,484'

-- Average Customer Balance
SELECT 
	ROUND(AVG(Total_Balance),2) as Total_Balance
FROM vw_transaction_analysis; -- '50,221.51'

-- Average Transaction Value
SELECT 
	ROUND(AVG(Transaction_Amount),2) as Average_Transaction_Value
FROM vw_transaction_analysis;  -- '2,542.71'

-- Active Branches
SELECT
	COUNT(DISTINCT Branch_ID) as Active_Branches 
    FROM vw_transaction_analysis
    WHERE Firm_Revenue IS NOT NULL
    AND   Expenses     IS NOT NULL
	AND	  Profit_Margin IS NOT NULL; -- 947
    
-- Average Profit Margin
WITH branches AS (
    SELECT DISTINCT
        Branch_ID,
        Profit_Margin
    FROM vw_transaction_analysis
    WHERE Branch_ID IS NOT NULL
      AND Profit_Margin IS NOT NULL
)

SELECT
    
    ROUND(AVG(Profit_Margin),2)  AS Average_Profit_Margin
FROM branches; -- 25.16

/*==============================================================
  9.2 CUSTOMER VALUE SCORING

  Create one customer-level record containing:

  • Current Balance
  • Transaction Activity
  • Investment Activity

  Then calculate a weighted Customer Value Score.

  Score Weights

  Current Balance .............. 40%
  Transaction Amount ........... 30%
  Investment Amount ............ 20%
  Average Transaction .......... 10%
==============================================================*/

 
CREATE OR REPLACE VIEW score_table AS

WITH customer AS (
    SELECT
        Customer_ID,
        Transaction_ID,
        Transaction_Date,
        Transaction_Amount,
        Total_Balance,
        Investment_Amount,

        ROW_NUMBER() OVER (
            PARTITION BY Customer_ID
            ORDER BY Transaction_Date DESC, Transaction_ID DESC
        ) AS rn

    FROM vw_transaction_analysis
),

current_balance AS (
    SELECT
        Customer_ID,
        COUNT(Transaction_ID) AS total_transactions,
        SUM(Transaction_Amount) AS total_transaction_amount,
        ROUND(AVG(Transaction_Amount), 2) AS avg_transaction_amount,
        MAX(Transaction_Amount) AS max_transaction_amount,
        SUM(Investment_Amount) AS total_investment_amount,
        MAX(
            CASE 
                WHEN rn = 1 THEN Total_Balance 
            END
        ) AS current_balance

    FROM customer
    GROUP BY Customer_ID
),

ranked AS (
    SELECT
        Customer_ID,
        total_transactions,
        total_transaction_amount,
        avg_transaction_amount,
        max_transaction_amount,
        total_investment_amount,
        current_balance,

        NTILE(4) OVER (
            ORDER BY total_transaction_amount
        ) AS total_transaction_quartile,

        NTILE(4) OVER (
            ORDER BY avg_transaction_amount
        ) AS avg_transaction_quartile,

        NTILE(4) OVER (
            ORDER BY max_transaction_amount
        ) AS max_transaction_quartile,

        NTILE(4) OVER (
            ORDER BY total_investment_amount
        ) AS total_investment_quartile,

        NTILE(4) OVER (
            ORDER BY current_balance
        ) AS current_balance_quartile

    FROM current_balance
),

customer_score AS (
    SELECT
        Customer_ID,
        total_transactions,
        total_transaction_amount,
        avg_transaction_amount,
        max_transaction_amount,
        total_investment_amount,
        current_balance,

        total_transaction_quartile,
        avg_transaction_quartile,
        max_transaction_quartile,
        total_investment_quartile,
        current_balance_quartile,

        ROUND(
              current_balance_quartile * 0.40
            + total_transaction_quartile * 0.30
            + total_investment_quartile * 0.20
            + avg_transaction_quartile * 0.10,
            2
        ) AS customer_value_score

    FROM ranked
)
SELECT * FROM customer_score ;

/*==============================================================
  9.3 CUSTOMER SEGMENTATION

  Business Rules

  🌟 Retain Customers
     High-value customers with strong balances and investments.

  💰 Cross-sell Customers
     High balances but relatively low investments.

  🎯 Target Customers
     Moderate balances with strong transaction activity.

  ⚠ Low Value Customers
     Customers who do not satisfy the above conditions.
==============================================================*/
--------------- Retain_Customers --------------
WITH high_value_retain AS (
    SELECT *
    FROM score_table
    WHERE customer_value_score >= 3.5
      AND current_balance_quartile = 4
      AND total_investment_quartile >= 3
)
SELECT * FROM high_value_retain; -- 458

--------------- Cross_Sells = High cash, Low investments -----------
WITH cross_sell AS(
					SELECT * 
					FROM score_table
                    WHERE current_balance_quartile = 4
                    AND  total_investment_quartile <= 2)
SELECT * FROM cross_sell; -- 789

--------------- Growth (Target) ----------------
-- Customers with growth potential
WITH target as (
				SELECT 	*
                FROM score_table
                WHERE current_balance_quartile IN (2, 3)
				AND total_transaction_quartile = 4)
SELECT * FROM target; -- 1963

------------- -- Low_Value --------------------
WITH customer_segmentation as (
				SELECT *,
                    CASE 
						WHEN customer_value_score >= 3.5
							AND current_balance_quartile = 4
							AND total_investment_quartile >= 3
						    THEN 'retain_customers'
						WHEN current_balance_quartile = 4
							AND  total_investment_quartile <= 2
                            THEN 'cross_sell_customers'
						WHEN current_balance_quartile IN (2,3)
							AND total_transaction_quartile = 4
							THEN 'target_customers'
						ELSE 'low_value_customers'
					END as segmentation
				FROM score_table)
-- SELECT * FROM customer_segmentation WHERE segmentation = 'low_value_customers'; -- 3125

SELECT
    segmentation,
    COUNT(*) AS customer_count
FROM customer_segmentation  GROUP BY segmentation;

-----------------------------------------------------------
/*==============================================================
  9.4 CUSTOMER BUSINESS VIEW

  Enrich customer scoring by adding:

  • Branch
  • Customer City
  • Customer Region

  This view supports branch and regional analysis.
==============================================================*/
CREATE OR REPLACE VIEW customer_business_view AS
SELECT
    s.*,

    CASE 
        WHEN s.customer_value_score >= 3.5
             AND s.current_balance_quartile = 4
             AND s.total_investment_quartile >= 3
        THEN 'retain_customers'

        WHEN s.current_balance_quartile = 4
             AND s.total_investment_quartile <= 2
        THEN 'cross_sell_customers'

        WHEN s.current_balance_quartile IN (2, 3)
             AND s.total_transaction_quartile = 4
        THEN 'target_customers'

        ELSE 'low_value_customers'
    END AS segmentation,

    c.Branch_ID,
    c.City,
    c.Region
FROM score_table AS s
LEFT JOIN customer_data AS c
    ON s.Customer_ID = c.Customer_ID;

/*==============================================================
  9.5 BRANCH ANALYTICS VIEW

  Combine customer performance with
  branch financial information.

  Added metrics

  • Firm Revenue
  • Expenses
  • Profit Margin
==============================================================*/

CREATE OR REPLACE VIEW branch_view AS
SELECT
    b.Branch_ID,
    b.City AS branch_city,
    b.Region AS branch_region,
    b.Firm_Revenue,
    b.Expenses,
    b.Profit_Margin,

    COUNT(DISTINCT cb.Customer_ID) AS total_customers,
    ROUND(AVG(cb.customer_value_score),2) AS avg_customer_value_score,
    ROUND(AVG(cb.current_balance),2) AS avg_current_balance,
    SUM(cb.total_transaction_amount) AS total_transaction_amount,
    SUM(cb.total_investment_amount) AS total_investment_amount

FROM bank_data AS b
LEFT JOIN customer_business_view AS cb
    ON b.Branch_ID = cb.Branch_ID

GROUP BY
    b.Branch_ID,
    b.City,
    b.Region,
    b.Firm_Revenue,
    b.Expenses,
    b.Profit_Margin;
/*==============================================================
  9.6 BRANCH PERFORMANCE ANALYSIS
==============================================================*/

---------------------------------------------------------------
-- KPI 1
-- Top 20 Branches by Customer Value Score
---------------------------------------------------------------


SELECT
    Branch_ID,
    total_customers,
    avg_customer_value_score
FROM branch_view
WHERE total_customers >= 3
ORDER BY avg_customer_value_score DESC, total_customers DESC
LIMIT 20;
---------------------------------------------------------------
-- KPI 2
-- Top 20 Branches by Current Balance
---------------------------------------------------------------

SELECT
    Branch_ID,
    total_customers,
    avg_current_balance
FROM branch_view
WHERE total_customers >= 3
ORDER BY avg_current_balance DESC
LIMIT 20;

---------------------------------------------------------------
-- KPI  3
-- Top 20 Branches by Investment Amount
---------------------------------------------------------------

SELECT
    Branch_ID,
    total_customers,
    total_investment_amount
FROM branch_view
WHERE total_customers >= 3
ORDER BY total_investment_amount DESC
LIMIT 20;

/*==============================================================
  9.7 BRANCH FINANCIAL PERFORMANCE
==============================================================*/


---------------------------------------------------------------
-- KPI 4
-- Top 20 Branches by Firm Revenue
---------------------------------------------------------------

SELECT
    Branch_ID,
    total_customers,
    avg_customer_value_score,
    Firm_Revenue
FROM branch_view
WHERE total_customers >= 3
ORDER BY Firm_Revenue DESC
LIMIT 20;
---------------------------------------------------------------
-- KPI 5
-- Top 20 Branches by Operating Expenses
---------------------------------------------------------------
SELECT
    Branch_ID,
    total_customers,
    avg_customer_value_score,
    Expenses
FROM branch_view
WHERE total_customers >= 3
ORDER BY Expenses DESC
LIMIT 20;
---------------------------------------------------------------
-- KPI 6
-- Top 20 Branches by Profit Margin
---------------------------------------------------------------
SELECT
    Branch_ID,
    total_customers,
    avg_customer_value_score,
    Profit_Margin
FROM branch_view
WHERE total_customers >= 3
ORDER BY Profit_Margin DESC
LIMIT 20;
---------------------------------------------------------------
/*==============================================================
  9.5 Monthly Transaction Trend

  Create a separate SQL view
==============================================================*/
CREATE OR REPLACE VIEW monthly_transaction_view AS
SELECT
    DATE_FORMAT(Transaction_Date, '%Y-%m-01') AS month_start,
    COUNT(Transaction_ID) AS total_transactions,
    SUM(Transaction_Amount) AS total_transaction_amount,
    SUM(Investment_Amount) AS total_investment_amount
FROM vw_transaction_analysis
GROUP BY DATE_FORMAT(Transaction_Date, '%Y-%m-01');
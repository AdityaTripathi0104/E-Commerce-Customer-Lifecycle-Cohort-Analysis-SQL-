# ----------------------------------------------CLEANING DATA STEP-------------------------------------------
#cleaned table we are doing our analysis in this
#Clean data for 541k dataset.
  -- 1. Create the high-quality table
  
DROP TABLE cleaned_retail;
CREATE TABLE cleaned_retail AS
SELECT 
    InvoiceNo,
    StockCode,
    Description,
    CAST(Quantity AS SIGNED) AS Quantity,
    -- Fix the date: Adjust the format '%m/%d/%Y %H:%i' if your CSV used a different one
    STR_TO_DATE(InvoiceDate, '%m/%d/%Y %H:%i') AS InvoiceDate,
    CAST(UnitPrice AS DECIMAL(10,2)) AS UnitPrice,
    CustomerID,
    Country
FROM online_retail
WHERE CustomerID IS NOT NULL 
  AND CustomerID <> ''          -- Removes "Ghost" customers
  AND Quantity > 0               -- Removes Returns
  AND UnitPrice > 0;             -- Removes adjustments/trash data
  
  
  #Checking cleaned_retail has no customer id with null or empty string value. this is our clean table analysis
  SELECT COUNT(*) FROM cleaned_retail WHERE CustomerID = '' OR CustomerID IS NULL; 
  
  #Checking for any returns in our dataset
  SELECT COUNT(*) FROM cleaned_retail WHERE Quantity <= 0;
  
  #Now are cleaned dataset original count on which we will do our co-hort analysis
  SELECT DISTINCT COUNT(*) FROM cleaned_retail;
  
  #---------------------STEPS TAKEN ON CLEANED DATA TO CLEAN IT MORE----------------------------------------------
  # STEP - 1
  #Removing bad stockcodes from the code for more improved data so the analysis is not skewed
SELECT StockCode, Description, COUNT(*) 
FROM cleaned_retail 
WHERE StockCode NOT REGEXP '^[0-9]' 
GROUP BY 1, 2;

# STEP - 2
#Checking for the duplicates in our tables
SELECT InvoiceNo, StockCode, CustomerID, Quantity, COUNT(*)
FROM cleaned_retail
GROUP BY 1, 2, 3, 4
HAVING COUNT(*) > 1;

# STEP - 3
#We are removing last month of 2011 cause it has very less values till date Dec 9th. This can give sudden drop in that month sales which it is not true coz
# the dataset ended right not that noone showed up after that.

#Fnal view table which we are going to use to calculate the birth month cohort
CREATE OR REPLACE VIEW retail_final_clean AS
SELECT DISTINCT 
    InvoiceNo,
    CustomerID,
    InvoiceDate,
    StockCode,
    Quantity,
    UnitPrice,
    DATE_FORMAT(InvoiceDate, '%Y-%m-01') AS InvoiceMonth,
    (Quantity * UnitPrice) AS Total_Sales_Per_Row
FROM cleaned_retail
WHERE CustomerID IS NOT NULL 
  AND CustomerID <> ''
  AND Quantity > 0 
  AND UnitPrice > 0
  AND StockCode REGEXP '^[0-9]'
  AND InvoiceDate < '2011-12-01'; -- This is the Dec 2011 "Cutoff"
  
  #Now seeing the count of our dataset
  SELECT COUNT(*) as Cleaned_Data_Record
  FROM retail_final_clean;
  
  #------------------------------------------MAIN CO-HORT ANALYSIS ON OUR CLEANED DATA IN OUR VIEW-----------------------------------------
  # CREATING A flow of CTE for mentioning  each sequence
  
  #CTE-1 - ALL CLEAN DATA IS IN THIS CTE.
  WITH Cleaned_data AS
  (
  SELECT 
			InvoiceNo,
            CustomerID,
            InvoiceDate,
            StockCode,
            Quantity,
            UnitPrice,
            DATE(InvoiceDate) AS InvoiceDateOnly,
            MONTH(InvoiceDate) AS Month1,
            (Quantity * UnitPrice) AS Total_Sales_Per_Row
FROM retail_final_clean
 #this is our view where all our clean data exists
),
Birth_Month AS
(
SELECT *,
MIN(Month1) OVER(PARTITION BY CustomerID) AS Birth_Month
FROM cleaned_data
)
SELECT *,
(Month1 - Birth_Month) as Frequency
FROM Birth_Month;



#Analysis_with_Other_Months AS
#(


#)
        
-- Calculate when each customer was "Born"
CREATE OR REPLACE VIEW customer_birth_months AS
SELECT 
    CustomerID, 
    MIN(InvoiceMonth) AS cohort_month
FROM retail_final_clean
GROUP BY CustomerID;

-- Map every purchase back to that Birth Month
CREATE OR REPLACE VIEW cohort_index_map AS
SELECT 
    f.CustomerID AS CustomerID,
    b.cohort_month AS cohort_month,
    f.InvoiceMonth,
    (PERIOD_DIFF(
        DATE_FORMAT(f.InvoiceDate, '%Y%m'), 
        DATE_FORMAT(STR_TO_DATE(b.cohort_month, '%Y-%m-%d'), '%Y%m')
    )) AS month_index,
    f.InvoiceNo,
    f.Total_sales_Per_Row as Total_Sales_Per_Row
FROM retail_final_clean f
JOIN customer_birth_months b ON f.CustomerID = b.CustomerID;

SELECT 
	CustomerID,
    SUM(Total_Sales_Per_Row) AS Total_Sales_By_Each_Users,
    month_index
FROM cohort_index_map
GROUP BY CustomerID, month_index;


-- 
SELECT 
    cohort_month,
    COUNT(DISTINCT CASE WHEN month_index = 0 THEN CustomerID END) AS Month_0,
    COUNT(DISTINCT CASE WHEN month_index = 1 THEN CustomerID END) AS Month_1,
    COUNT(DISTINCT CASE WHEN month_index = 2 THEN CustomerID END) AS Month_2,
    COUNT(DISTINCT CASE WHEN month_index = 3 THEN CustomerID END) AS Month_3,
    COUNT(DISTINCT CASE WHEN month_index = 4 THEN CustomerID END) AS Month_4,
    COUNT(DISTINCT CASE WHEN month_index = 5 THEN CustomerID END) AS Month_5,
    COUNT(DISTINCT CASE WHEN month_index = 6 THEN CustomerID END) AS Month_6,
    COUNT(DISTINCT CASE WHEN month_index = 7 THEN CustomerID END) AS Month_7,
    COUNT(DISTINCT CASE WHEN month_index = 8 THEN CustomerID END) AS Month_8,
    COUNT(DISTINCT CASE WHEN month_index = 9 THEN CustomerID END) AS Month_9,
    COUNT(DISTINCT CASE WHEN month_index = 10 THEN CustomerID END) AS Month_10,
    COUNT(DISTINCT CASE WHEN month_index = 11 THEN CustomerID END) AS Month_11
FROM cohort_index_map
GROUP BY cohort_month
ORDER BY cohort_month;

SELECT 
    cohort_month,
    Month_0,
    ROUND(Month_1 / Month_0 * 100, 2) AS Month_1_pct,
    ROUND(Month_2 / Month_0 * 100, 2) AS Month_2_pct,
    ROUND(Month_3 / Month_0 * 100, 2) AS Month_3_pct,
    ROUND(Month_4 / Month_0 * 100, 2) AS Month_4_pct,
    ROUND(Month_5 / Month_0 * 100, 2) AS Month_5_pct,
    ROUND(Month_6 / Month_0 * 100, 2) AS Month_6_pct,
    ROUND(Month_7 / Month_0 * 100, 2) AS Month_7_pct,
    ROUND(Month_8 / Month_0 * 100, 2) AS Month_8_pct,
    ROUND(Month_9 / Month_0 * 100, 2) AS Month_9_pct,
    ROUND(Month_10 / Month_0 * 100, 2) AS Month_10_pct,
    ROUND(Month_11 / Month_0 * 100, 2) AS Month_11_pct
FROM (
    -- This is your previous pivot query wrapped in a subquery
    SELECT 
        cohort_month,
        COUNT(DISTINCT CASE WHEN month_index = 0 THEN CustomerID END) AS Month_0,
        COUNT(DISTINCT CASE WHEN month_index = 1 THEN CustomerID END) AS Month_1,
        COUNT(DISTINCT CASE WHEN month_index = 2 THEN CustomerID END) AS Month_2,
        COUNT(DISTINCT CASE WHEN month_index = 3 THEN CustomerID END) AS Month_3,
        COUNT(DISTINCT CASE WHEN month_index = 4 THEN CustomerID END) AS Month_4,
        COUNT(DISTINCT CASE WHEN month_index = 5 THEN CustomerID END) AS Month_5,
        COUNT(DISTINCT CASE WHEN month_index = 6 THEN CustomerID END) AS Month_6,
        COUNT(DISTINCT CASE WHEN month_index = 7 THEN CustomerID END) AS Month_7,
        COUNT(DISTINCT CASE WHEN month_index = 8 THEN CustomerID END) AS Month_8,
        COUNT(DISTINCT CASE WHEN month_index = 9 THEN CustomerID END) AS Month_9,
        COUNT(DISTINCT CASE WHEN month_index = 10 THEN CustomerID END) AS Month_10,
        COUNT(DISTINCT CASE WHEN month_index = 11 THEN CustomerID END) AS Month_11
    FROM cohort_index_map
    GROUP BY cohort_month
) AS pivot_counts
ORDER BY cohort_month;

# --------------------------Average Revenue Per User (ARPU) ---------------------------------------------
            
WITH Cleaned_data AS
  (
  SELECT 
			InvoiceNo,
            CustomerID,
            InvoiceDate,
            StockCode,
            Quantity,
            UnitPrice,
            DATE(InvoiceDate) AS InvoiceDateOnly,
            MONTH(InvoiceDate) AS Month1,
            (Quantity * UnitPrice) AS Total_Sales_Per_Row
FROM retail_final_clean
)
SELECT * FROM Cleaned_data;

/*******************************************************************************
PHASE 3: REVENUE ANALYSIS (ARPU - Average Revenue Per User)
Goal: Measure the average "Wallet Share" of each cohort over time.
*******************************************************************************/

-- STEP 1: Define User-Level Granularity
-- We must roll up all transactions into a single "Monthly Total" per Customer.
--
-- ❌ MISTAKE TO AVOID: 
-- Using AVG(Total_Sales_Per_Row) directly on the transaction table.
-- WHY: This averages "Line Items" (Invoices), not "People." 
-- A customer buying 50 cheap items would skew the average downward incorrectly.
--
-- ✅ BEST PRACTICE: 
-- SUM first (Total spend per user), then AVG later (Mean spend of the cohort).

WITH user_monthly_spending AS (
    SELECT 
        CustomerID,
        cohort_month,
        month_index,
        SUM(Total_Sales_Per_Row) AS total_spent_by_user_this_month
    FROM cohort_index_map
    GROUP BY CustomerID, cohort_month, month_index
)

-- STEP 2: The ARPU Pivot Matrix
-- We use AVG() on our summed values to find the "Typical Spend" per active user.
-- 
-- ❌ MISTAKE TO AVOID: 
-- Including $0 or NULLs for customers who didn't return.
-- WHY: That would give you "Revenue per Subscriber." 
-- ARPU specifically measures the value of users who were ACTIVE in that month.
--
-- ✅ BEST PRACTICE:
-- SQL's AVG() function automatically ignores NULLs generated by the CASE WHEN,
-- ensuring we only average the customers who actually made a purchase.

SELECT 
    cohort_month,
    -- Month_0 represents the "Acquisition Value" (Initial Buy-in)
    ROUND(AVG(CASE WHEN month_index = 0 THEN total_spent_by_user_this_month END), 2) AS ARPU_Month_0,
    ROUND(AVG(CASE WHEN month_index = 1 THEN total_spent_by_user_this_month END), 2) AS ARPU_Month_1,
    ROUND(AVG(CASE WHEN month_index = 2 THEN total_spent_by_user_this_month END), 2) AS ARPU_Month_2,
    ROUND(AVG(CASE WHEN month_index = 3 THEN total_spent_by_user_this_month END), 2) AS ARPU_Month_3,
    ROUND(AVG(CASE WHEN month_index = 4 THEN total_spent_by_user_this_month END), 2) AS ARPU_Month_4,
    ROUND(AVG(CASE WHEN month_index = 5 THEN total_spent_by_user_this_month END), 2) AS ARPU_Month_5,
    ROUND(AVG(CASE WHEN month_index = 6 THEN total_spent_by_user_this_month END), 2) AS ARPU_Month_6,
    ROUND(AVG(CASE WHEN month_index = 7 THEN total_spent_by_user_this_month END), 2) AS ARPU_Month_7,
    ROUND(AVG(CASE WHEN month_index = 8 THEN total_spent_by_user_this_month END), 2) AS ARPU_Month_8,
    ROUND(AVG(CASE WHEN month_index = 9 THEN total_spent_by_user_this_month END), 2) AS ARPU_Month_9,
    ROUND(AVG(CASE WHEN month_index = 10 THEN total_spent_by_user_this_month END), 2) AS ARPU_Month_10,
    ROUND(AVG(CASE WHEN month_index = 11 THEN total_spent_by_user_this_month END), 2) AS ARPU_Month_11
FROM user_monthly_spending
GROUP BY cohort_month
ORDER BY cohort_month;

/*******************************************************************************
PHASE 4: CHURN ANALYSIS (The Leaky Bucket)
Goal: Identify which customers have officially stopped engaging with the brand.
*******************************************************************************/

CREATE OR REPLACE VIEW customer_churn_status AS
WITH last_purchase AS (
    SELECT 
        CustomerID,
        MAX(InvoiceDate) AS last_visit_date,
        -- The "Snapshot Date" is the day our data ends
        '2011-12-01' AS snapshot_date
    FROM cleaned_retail
    GROUP BY CustomerID
)
SELECT 
    *,
    -- Calculate days since last visit
    DATEDIFF(snapshot_date, last_visit_date) AS days_since_last_purchase,
    -- Define Churn: If they haven't visited in > 90 days, they are CHURNED
    CASE 
        WHEN DATEDIFF(snapshot_date, last_visit_date) > 90 THEN 'Churned'
        ELSE 'Active'
    END AS customer_status
FROM last_purchase;

#The "Big Picture" Check
# First, run this quick query to see the total split. This gives you the "Baseline" for the entire business.
SELECT 
    customer_status, 
    COUNT(CustomerID) AS customer_count,
    ROUND(COUNT(CustomerID) * 100.0 / SUM(COUNT(CustomerID)) OVER(), 2) AS percentage
FROM customer_churn_status
GROUP BY customer_status;

# The Cohort Churn Analysis (The Pivot)
# This is the most important part of Phase 4. We are going to join your customer_churn_status back to your customer_birth_months to see which "Birth Month" produces the most loyal customers.
SELECT 
    b.cohort_month,
    COUNT(CASE WHEN s.customer_status = 'Active' THEN s.CustomerID END) AS Active_Customers,
    COUNT(CASE WHEN s.customer_status = 'Churned' THEN s.CustomerID END) AS Churned_Customers,
    ROUND(
        COUNT(CASE WHEN s.customer_status = 'Churned' THEN s.CustomerID END) * 100.0 / COUNT(s.CustomerID), 
        2
    ) AS Churn_Rate_Percentage
FROM customer_birth_months b
JOIN customer_churn_status s ON b.CustomerID = s.CustomerID
GROUP BY b.cohort_month
ORDER BY b.cohort_month;

/*******************************************************************************
PHASE 5: REVENUE RETENTION (NRR - Net Revenue Retention)
Goal: Track the total dollar value of each cohort over its lifetime.
*******************************************************************************/

-- ❌ MISTAKE TO AVOID: 
-- Thinking that declining Retention % always means declining Revenue.
-- ⚠️ WHY: 
-- A cohort could lose 50% of its people, but if the remaining 50% double 
-- their spending (High ARPU), the Revenue Retention stays at 100%.

-- ✅ BEST PRACTICE: 
-- Calculate the "Total Sales" per cohort per month. 
-- This reveals if the "Loyal Core" is out-spending the "Churned" loss.

WITH cohort_revenue AS (
    SELECT 
        cohort_month,
        month_index,
        SUM(Total_Sales_Per_Row) AS total_revenue_this_month
    FROM cohort_index_map
    GROUP BY 1, 2
)
SELECT 
    cohort_month,
    -- We are looking at the TOTAL PILE of money now, not the average
    ROUND(SUM(CASE WHEN month_index = 0 THEN total_revenue_this_month END), 2) AS Revenue_Month_0,
    ROUND(SUM(CASE WHEN month_index = 1 THEN total_revenue_this_month END), 2) AS Revenue_Month_1,
    ROUND(SUM(CASE WHEN month_index = 2 THEN total_revenue_this_month END), 2) AS Revenue_Month_2,
    ROUND(SUM(CASE WHEN month_index = 3 THEN total_revenue_this_month END), 2) AS Revenue_Month_3,
    ROUND(SUM(CASE WHEN month_index = 4 THEN total_revenue_this_month END), 2) AS Revenue_Month_4,
    ROUND(SUM(CASE WHEN month_index = 5 THEN total_revenue_this_month END), 2) AS Revenue_Month_5,
    ROUND(SUM(CASE WHEN month_index = 6 THEN total_revenue_this_month END), 2) AS Revenue_Month_6,
    ROUND(SUM(CASE WHEN month_index = 7 THEN total_revenue_this_month END), 2) AS Revenue_Month_7,
    ROUND(SUM(CASE WHEN month_index = 8 THEN total_revenue_this_month END), 2) AS Revenue_Month_8,
    ROUND(SUM(CASE WHEN month_index = 9 THEN total_revenue_this_month END), 2) AS Revenue_Month_9,
    ROUND(SUM(CASE WHEN month_index = 10 THEN total_revenue_this_month END), 2) AS Revenue_Month_10,
    ROUND(SUM(CASE WHEN month_index = 11 THEN total_revenue_this_month END), 2) AS Revenue_Month_11
FROM cohort_revenue
GROUP BY cohort_month
ORDER BY cohort_month;

/*******************************************************************************
PHASE 5: NET REVENUE RETENTION (NRR) PERCENTAGE
Goal: Convert raw dollars into a growth/decay percentage.
Formula: (Current Month Revenue / Starting Month Revenue) * 100
*******************************************************************************/

WITH cohort_revenue AS (
    -- First, we get the total dollars per cohort per month
    SELECT 
        cohort_month,
        month_index,
        SUM(Total_Sales_Per_Row) AS monthly_revenue
    FROM cohort_index_map
    GROUP BY 1, 2
),
base_revenue AS (
    -- Second, we "pin" the Month 0 revenue for every cohort to use as a denominator
    SELECT 
        cohort_month,
        monthly_revenue AS starting_revenue
    FROM cohort_revenue
    WHERE month_index = 0
)
SELECT 
    r.cohort_month,
    -- ❌ MISTAKE TO AVOID: 
    -- Forgetting to handle "Division by Zero" or NULLs if a month had no sales.
    -- ✅ BEST PRACTICE:
    -- Use ROUND() and multiply by 100 to make the result readable as a % (e.g., 89.5).
    
    ROUND((MAX(CASE WHEN month_index = 0 THEN monthly_revenue END) / b.starting_revenue) * 100, 2) AS NRR_Month_0,
    ROUND((MAX(CASE WHEN month_index = 1 THEN monthly_revenue END) / b.starting_revenue) * 100, 2) AS NRR_Month_1,
    ROUND((MAX(CASE WHEN month_index = 2 THEN monthly_revenue END) / b.starting_revenue) * 100, 2) AS NRR_Month_2,
    ROUND((MAX(CASE WHEN month_index = 3 THEN monthly_revenue END) / b.starting_revenue) * 100, 2) AS NRR_Month_3,
    ROUND((MAX(CASE WHEN month_index = 4 THEN monthly_revenue END) / b.starting_revenue) * 100, 2) AS NRR_Month_4,
    ROUND((MAX(CASE WHEN month_index = 5 THEN monthly_revenue END) / b.starting_revenue) * 100, 2) AS NRR_Month_5,
    ROUND((MAX(CASE WHEN month_index = 6 THEN monthly_revenue END) / b.starting_revenue) * 100, 2) AS NRR_Month_6,
    ROUND((MAX(CASE WHEN month_index = 7 THEN monthly_revenue END) / b.starting_revenue) * 100, 2) AS NRR_Month_7,
    ROUND((MAX(CASE WHEN month_index = 8 THEN monthly_revenue END) / b.starting_revenue) * 100, 2) AS NRR_Month_8,
    ROUND((MAX(CASE WHEN month_index = 9 THEN monthly_revenue END) / b.starting_revenue) * 100, 2) AS NRR_Month_9,
    ROUND((MAX(CASE WHEN month_index = 10 THEN monthly_revenue END) / b.starting_revenue) * 100, 2) AS NRR_Month_10,
    ROUND((MAX(CASE WHEN month_index = 11 THEN monthly_revenue END) / b.starting_revenue) * 100, 2) AS NRR_Month_11
FROM cohort_revenue r
JOIN base_revenue b ON r.cohort_month = b.cohort_month
GROUP BY r.cohort_month
ORDER BY r.cohort_month;
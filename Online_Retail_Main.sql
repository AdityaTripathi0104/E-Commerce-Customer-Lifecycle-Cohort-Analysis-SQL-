use Project_SQL_Online_Retail;

DROP TABLE online_retail;

TRUNCATE TABLE online_retail; -- This clears the table so you can start fresh

SHOW TABLES;

SHOW VARIABLES LIKE "secure_file_priv";

USE project_sql_online_retail;

CREATE TABLE IF NOT EXISTS online_retail (
    InvoiceNo VARCHAR(20),
    StockCode VARCHAR(20),
    Description VARCHAR(255),
    Quantity INT,
    InvoiceDate VARCHAR(50), -- We keep as VARCHAR for now to use STR_TO_DATE later
    UnitPrice DECIMAL(10,2),
    CustomerID VARCHAR(20),
    Country VARCHAR(50)
);

LOAD DATA INFILE '/Users/adityatripathi/Documents/Projects-DS/SQL_Tutorials_and_Projects-1/E-commerce Customer Retention/data 2.csv'
INTO TABLE online_retail 
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS; -- Skips the header (InvoiceNo, StockCode, etc.)

LOAD DATA LOCAL INFILE '/Users/adityatripathi/Documents/Projects-DS/SQL_Tutorials_and_Projects-1/E-commerce Customer Retention/data 2.csv' 
INTO TABLE online_retail 
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\n' 
IGNORE 1 ROWS;

SET GLOBAL local_infile = 1;



SELECT * FROM online_retail;


# ----------------------------------------------CLEANING DATA STEP-------------------------------------------
#STEP - 1 : REMOVING NULL VALUES WHERE CUSTOMER_ID IS BLANK OR QUANTITY IS NEGATIVE


# LET'S LOOK COLUMN WISE - FIRST COLUMN INVOICE NO. AND SUBSEQUENTLY
# Checking Whether my column is starting with any character C
SELECT InvoiceNo
FROM online_retail
WHERE InvoiceNo LIKE 'C%';

# Checking the invoice is all numbers
SELECT DISTINCT InvoiceNo 
FROM online_retail 
WHERE InvoiceNo REGEXP '[^0-9]';

#Checking length of all the rows the length of Invoice is 6.
SELECT InvoiceNo, LENGTH(InvoiceNo) 
FROM online_retail 
WHERE LENGTH(InvoiceNo) > 6
ORDER BY LENGTH(InvoiceNo) DESC;

#Checking with help of hexadecimal HEX() function
-- This bypasses filters to show us what the data actually looks like
SELECT InvoiceNo, HEX(InvoiceNo) as hex_val
FROM online_retail 
LIMIT 10;

SELECT InvoiceNo
FROM online_retail
WHERE InvoiceNo LIKE '%C%';

SELECT LENGTH(InvoiceNo) as len, COUNT(*) 
FROM online_retail 
GROUP BY len;

SELECT COUNT(*) FROM online_retail;

#Checking unique InvoiceNo its too much now. 
SELECT COUNT(DISTINCT InvoiceNo) AS unique_orders
FROM online_retail;

SELECT COUNT(*), InvoiceNo 
FROM online_retail
GROUP BY InvoiceNo;

#The "True Duplicate" Check
#This is a more advanced industry technique. You want to see if there are any rows that are exact copies of each other.
SELECT COUNT(*) 
FROM (
SELECT InvoiceNo, StockCode, CustomerID, Quantity, InvoiceDate, COUNT(*)
FROM online_retail
GROUP BY InvoiceNo, StockCode, CustomerID, Quantity, InvoiceDate
HAVING COUNT(*) > 1) T; # We have 4993 rows which are duplicate in our datasets and this is big.  We can take care of it at our cohort analysis.

#----------------------SECOND AND THIRD COLUMNS---------------------------------
#CHECKING THE LENGTH OF THE ALL THE STOCKCODE ANOTHER COLUMN AND COUNTING. IF THE COUNT IS SAME AS TOTAL COUNT OF ALL THE ROWS THEN WE ARE GOOD. 
SELECT length1, COUNT(*) FROM 
(SELECT LENGTH(StockCode) as length1
FROM online_retail) T
GROUP BY length1;



#CHECKING DISTINCT STOCKCODES AND ITS DESCRIPTION. The count here is 2388. We have these many unique products which are sold. Total of 2388.
SELECT COUNT(*)
FROM 
(
SELECT DISTINCT StockCode, Description
FROM online_retail
) T;

#This is big too. We are getting some real shit here. You can see we have different sets of StockCode lengths. 
SELECT LENGTH(StockCode) AS code_length, COUNT(*) AS total_rows
FROM online_retail
GROUP BY LENGTH(StockCode)
ORDER BY code_length;

#Now we are going to check we have multiple description for same stockcodes. So, we found only 15 records out of 2388 products which had multiple descriptions entered by mistake.
SELECT StockCode, COUNT(DISTINCT Description) as distinct_descriptions
FROM online_retail
GROUP BY StockCode
HAVING COUNT(DISTINCT Description) > 1;

# Let's see what these are stockcodes with weird lengths. Then we will see how can we remove them.
SELECT StockCode FROM online_retail WHERE LENGTH(StockCode) = 1;

SELECT LENGTH(StockCode) AS code_length, COUNT(*) AS total_rows
FROM online_retail
GROUP BY LENGTH(StockCode)
ORDER BY code_length;

# These are the ones which we need to decide to keep or remove for our cohort analysis.
SELECT DISTINCT StockCode, Description, LENGTH(StockCode) as length1
FROM online_retail 
WHERE LENGTH(StockCode) NOT IN (5,6);

#------------------------------------UnitPrice AND Quantity COLUMNS---------------------------------
# Running min and max boundaries for both unit price and quantity columns
SELECT 
MIN(UnitPrice) as min_up,
MAX(UnitPrice) as max_up,
MIN(Quantity) as min_qty,
MAX(Quantity) as max_qty
FROM online_retail;

# we have few columns which have minimum unit price as 0. What are those?
SELECT DISTINCT *
FROM online_retail
WHERE UnitPrice = 0;

#BAD RECORDS IN THIS QUERY
SELECT *
FROM online_retail
WHERE UnitPrice = 0 OR Quantity < 0 OR LENGTH(StockCode) NOT IN (5,6);

# CLEAN RECORDS FOR THIS TABLE WHICH WE CAN USE FOR OUR COHORT ANALYSIS.
SELECT COUNT(*) 
FROM 
(
SELECT DISTINCT *
FROM online_retail
WHERE UnitPrice > 0 AND LENGTH(StockCode) IN (5,6) AND Quantity > 0
) T;

# -------------------------------------NOW LOOKING ON OUR CUSTOMERID COLUMN -------------------------------------
SELECT LENGHT(CustomerID), 
SET SQL_SAFE_UPDATES = 0;

UPDATE online_retail 
SET CustomerID = NULL 
WHERE CustomerID = '' OR CustomerID = ' ';

SET SQL_SAFE_UPDATES = 1;

SELECT CustomerID, count1
FROM 
(
SELECT CustomerID, COUNT(*) as count1
 FROM online_retail
where CustomerID IS NOT NULL
GROUP BY CustomerID) T
ORDER BY count1 ASC LIMIT 1;

SELECT MIN(CustomerID) FROM online_retail;

SELECT CustomerID FROM online_retail where CustomerID IS NULL;

select count(*) FROM 
(SELECT *
FROM online_retail
WHERE CustomerID IS NULL OR LENGTH(CustomerID) > 5) T;

# CLEAN RECORDS FOR THIS TABLE WHICH WE CAN USE FOR OUR COHORT ANALYSIS. (For 24k dataset)
-- This will be the foundation for your Cohort Analysis
SELECT DISTINCT
    InvoiceNo,
    StockCode,
    Description,
    Quantity,
    UnitPrice,
    CustomerID,
    -- Transforming the date here so it's ready for the next step
    DATE(STR_TO_DATE(InvoiceDate, '%m/%d/%Y %k:%i')) AS invoice_date,
    -- Getting timestamps too just in case.
    TIME(STR_TO_DATE(InvoiceDate, '%m/%d/%Y %k:%i')) AS invoice_time,
    -- Getting month for all the records just in case.
    MONTH(STR_TO_DATE(InvoiceDate, '%m/%d/%Y %k:%i')) AS invoice_month
FROM online_retail
WHERE CustomerID IS NOT NULL      -- Rule 1: Must have a passport (ID)
  AND UnitPrice > 0               -- Rule 2: No freebies or adjustments
  AND Quantity > 0      		  -- This removes all returns/cancellations
  AND LENGTH(StockCode) IN (5, 6) -- Rule 3: Real products only
  AND LENGTH(CustomerID) = 5;     -- Rule 4: Standard IDs only (if yours are all 5)
  
  #Clean data for 541k dataset.
  -- 1. Create the high-quality table
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
  SELECT COUNT(*) FROM cleaned_retail;
#--------------------------------CO-HORT ANALYSIS-----------------------------------

-- Checking whether UnitPrice = 0 rows must be included or not. No, coz its better we have economic behaviour of customer.
SELECT description 
FROM online_retail 
WHERE unitPrice = 0;

SELECT invoicedate, CustomerID
FROM online_retail;

WITH CTE_EX1 AS
(
SELECT DISTINCT
    InvoiceNo,
    StockCode,
    Description,
    Quantity,
    UnitPrice,
    CustomerID,
    -- Transforming the date here so it's ready for the next step
    DATE(STR_TO_DATE(InvoiceDate, '%m/%d/%Y %k:%i')) AS invoice_date,
    -- Getting timestamps too just in case.
    TIME(STR_TO_DATE(InvoiceDate, '%m/%d/%Y %k:%i')) AS invoice_time,
    -- Month column just in case
     MONTH(STR_TO_DATE(InvoiceDate, '%m/%d/%Y %k:%i')) AS invoice_month
FROM online_retail
WHERE CustomerID IS NOT NULL      -- Rule 1: Must have a passport (ID)
  AND UnitPrice > 0               -- Rule 2: No freebies or adjustments
  AND LENGTH(StockCode) IN (5, 6) -- Rule 3: Real products only
  AND LENGTH(CustomerID) = 5     -- Rule 4: Standard IDs only (if yours are all 5)
  )
  , CTE_EX2 AS
  (
SELECT MIN(invoice_date) AS first_purchase_date, CustomerID,
DATE_FORMAT(MIN(invoice_date), '%Y-%m-01') AS cohort_month
FROM CTE_EX1
GROUP BY CustomerID
)
SELECT ce2.CustomerID
FROM CTE_EX1 ce1 JOIN CTE_EX2 ce2
ON ce1.CustomerID = ce2.CustomerID
AND ce1.invoice_date >= ce2.cohort_month  ;

WITH CTE_EX1 AS (
    -- Your clean data
    SELECT DISTINCT
        InvoiceNo,
        CustomerID,
        DATE(STR_TO_DATE(InvoiceDate, '%m/%d/%Y %k:%i')) AS invoice_date
    FROM online_retail
    WHERE CustomerID IS NOT NULL
      AND UnitPrice > 0
      AND LENGTH(StockCode) IN (5, 6)
      AND LENGTH(CustomerID) = 5
),
CTE_EX2 AS (
    -- Identifying the "Birth Month" for each customer
    SELECT 
        CustomerID,
        DATE_FORMAT(MIN(invoice_date), '%Y-%m-01') AS cohort_month
    FROM CTE_EX1
    GROUP BY CustomerID
)
-- Step 3: Create the Timeline
SELECT 
    ce1.CustomerID,
    ce1.invoice_date,
    ce2.cohort_month,
    -- Calculate the "Age" of the customer in months (Month Index)
    (YEAR(ce1.invoice_date) - YEAR(ce2.cohort_month)) * 12 + 
    (MONTH(ce1.invoice_date) - MONTH(ce2.cohort_month)) AS month_index
FROM CTE_EX1 ce1 
JOIN CTE_EX2 ce2 ON ce1.CustomerID = ce2.CustomerID
ORDER BY ce1.CustomerID, ce1.invoice_date;


SELECT * FROM online_retail;

# E-Commerce Customer Lifecycle & Cohort Analysis (SQL)

**A comprehensive SQL-based analytical framework for evaluating customer retention, unit economics (ARPU), and revenue health using a business-driven cohort methodology.**

---

## Phase 0 — Business Framing

### **Objective**
The primary objective of this project is to quantify **customer loyalty** and **financial sustainability** over time. By segmenting customers into acquisition cohorts, the analysis identifies which groups drive long-term revenue and where the business is experiencing "leakage" in the customer lifecycle.

### **Analytical Focus**
* **Retention:** Determining the "stickiness" of the product across different time-horizons.
* **Monetization (ARPU):** Tracking the evolution of average spend per user as a cohort ages.
* **Churn:** Identifying the "leakage points" in the customer lifecycle.
* **Net Revenue Retention (NRR):** Measuring the total financial health and growth/decay of specific customer groups.

### **Business Questions**
1. Is customer retention improving or declining based on the month of acquisition?
2. Do survivors of a cohort increase their spending over time (Expansion Revenue)?
3. What is the impact of churn on the total revenue baseline per cohort?

---

## Phase 1 — Data Validation & Cleaning

### **Objective**
Ensure the transactional dataset is sanitized and structured for longitudinal analysis (tracking the same user over 12 months).

### **Data Validation Checks**
* **Granularity Control:** Verified CustomerID presence; filtered out ~135k rows of anonymous traffic to ensure cohort tracking is possible.
* **Negative Value Logic:** Identified and isolated "C" prefix invoices (Returns) to ensure revenue is not artificially inflated.
* **Structural Cleaning:** Removed non-product transactions (e.g., POSTAGE, BANK CHARGES) to focus purely on inventory-driven revenue.

> **Key Takeaway:** Phase 1 establishes a **"Clean Revenue" baseline**, ensuring that retention and spending metrics are not skewed by administrative noise or incomplete data.

---

## Phase 2 — Retention Matrix Construction

### **Objective**
Map the **"Birth Month"** of every customer and track their return behavior over an 11-month horizon.

### **Key Analyses Performed**
* **Cohort Definition:** Established the First_Purchase_Month for every unique identifier.
* **Index Mapping:** Calculated the month_index (the distance in months from the first purchase) using PERIOD_DIFF.
* **The Retention Pivot:** Constructed a matrix showing the percentage of users returning in each subsequent month.

> **Key Takeaway:** Phase 2 identified the **Dec 2010 cohort** as a statistical outlier with significantly higher long-term retention compared to mid-year acquisitions.

---

## Phase 3 — Monetization (ARPU) Dynamics

### **Objective**
Transition from "counting people" to "counting value" by analyzing the **Average Revenue Per User (ARPU)**.

### **Analytical Focus**
* **Double Aggregation:** Sales were summed at the user level before being averaged at the cohort level to prevent transaction-frequency bias.
* **Expansion Revenue Detection:** Investigated if "surviving" customers spend more over time to offset the loss of churned users.

> **Key Takeaway:** While retention percentages naturally decay, the **ARPU for the Dec 2010 cohort increased by ~78%** between Month 0 and Month 11, indicating a high-value "loyal core."

---

## Phase 4 — Churn & Lifecycle Analysis

### **Objective**
Define "The End" of the customer lifecycle and identify cohorts with high **"Early-Death"** rates.

### **Key Analyses Performed**
* **90-Day Churn Definition:** Using a MAX(InvoiceDate) logic, users were flagged as "Churned" if their last purchase exceeded 90 days from the dataset snapshot.
* **Cohort Health Comparison:** Directly compared "Active" vs. "Churned" counts per birth month.

> **Key Takeaway:** The **April 2011 cohort** was identified as a "Low-Quality" group, with churned customers outnumbering active ones (**52% churn rate**).

---

## Phase 5 — Synthesis & Net Revenue Retention (NRR)

### **Objective**
Combine Retention and ARPU into a single "Health KPI": **Net Revenue Retention (NRR).**

### **Key Outputs**
* **NRR Percentage Matrix:** Calculated as (Current Month Revenue / Starting Month Revenue) * 100.
* **Recovery Tracking:** Quantified how much "lost" revenue from churn is recovered by the increased spending of survivors.
* **The "Golden Goal" Metric:** Identified months where NRR approaches or exceeds 100% (Negative Churn).

> **Key Takeaway:** The Dec 2010 cohort recovered **89.59%** of its original revenue by Month 11, despite losing 30% of its customer base, proving the power of expansion revenue.

---

## Phase 6 — Validation, Assumptions & Limitations

### **Validation Notes**
* **Immature Data:** Churn rates for late-2011 cohorts are "immature" due to the 90-day window and require a longer observation window for full confirmation.
* **Wholesale Bias:** High ARPU in the Dec 2010 cohort suggests a mix of B2B and B2C customers, which may skew "typical" consumer benchmarks.

### **Limitations**
* **Top-line Focus:** Analysis focuses on Revenue; profitability and margins are not included in this dataset.
* **Causality:** Results are associational; specific marketing triggers for cohort behavior are not available.

---

## Phase 7 — Final Packaging & Project Overview

### **Repository Structure**

* **sql/ — Phase-wise SQL analysis (Phases 1–5)** — View definitions and noise removal, Pivot logic for the retention matrix, ARPU and NRR calculations.
* **README.md** — Business narrative and insights.

### **Tech Stack**
* **SQL:** MySQL 8.0 (CTEs, Window Functions, Period Math).
* **Concepts:** Unit Economics, Cohort Analysis, Expansion Revenue, Lifecycle Marketing.

### **Project Summary**
This project demonstrates an **end-to-end customer lifecycle analysis**, moving from raw transactional data to validated growth KPIs. It provides the framework necessary to distinguish between "High-Volume" acquisition months and "High-Quality" loyalty months.

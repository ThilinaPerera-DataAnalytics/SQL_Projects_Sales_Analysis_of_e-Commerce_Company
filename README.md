# Sales Analysis with SQL / PostgreSQL
```
Capstone Project
Intermediate SQL for Data Analytics
by Luke Barousse & Kelly Adams
```
---
![coverimage]()

---
## Overview
Analysis of customer behavior, retention, and lifetime value for an e-commerce company to improve customer retention and maximize revenue.

[![LinkedIn](https://img.shields.io/badge/LinkedIn-%230077B5.svg?logo=linkedin&logoColor=white)](https://linkedin.com/in/thilina-perera-148aa934/)
---

## 🗂️ Project Folder Structure
```yml
SQL_Projects_Sales_Analysis_of_e-Commerce_Company 
│
├── data/
│   └── contoso_100k.sql        # Schema + table creation
│
├── visuals/
│   ├── Cohort_Analysis.pbix           # Final Power BI report
│   └── visuals_screenshots           # PNG exports of dashboards
│
├── cover_image.png
├── LICENSE.md
├── README.md                          # Project documentation
└── .gitignore
```
---
## Business Questions
1. **Customer Segmentation:** <br> Who are our most valuable customers?
2. **Cohort Analysis:** <br> How do different customer groups generate revenue?
3. **Retention Analysis:** <br> Which customers haven't purchased recently?
---
## Clean Up Data and Create a View

[**🖥️ Query**](view_ca.sql)
```sql
CREATE OR REPLACE VIEW cohort_analysis

AS WITH customer_revenue AS (
   SELECT
      s.customerkey, s.orderdate,
      sum(s.quantity * s.netprice * s.exchangerate) AS total_net_revenue,
      count(s.orderkey) AS num_orders,
      max(c.countryfull::text) AS countryfull,
      max(c.age) AS age,
      max(c.givenname::text) AS givenname,
      max(c.surname::text) AS surname
   FROM sales s
   LEFT JOIN customer c ON s.customerkey = c.customerkey
   GROUP BY s.customerkey, s.orderdate
   ORDER BY s.customerkey, s.orderdate
)
 SELECT
   customerkey, orderdate, total_net_revenue, num_orders, countryfull, age,
   concat(TRIM(BOTH FROM givenname), ' ', TRIM(BOTH FROM surname)) AS cleaned_name,
   min(orderdate) OVER (PARTITION BY customerkey) AS first_purchase_date,
   EXTRACT(year FROM min(orderdate) OVER (PARTITION BY customerkey)) AS cohort_year
FROM customer_revenue cr;
```

- Aggregated sales and customer data into revenue metrics
- Calculated first purchase dates for cohort analysis
- Created view combining transactions and customer details
---
## 🛠️ Tech Stack
- *Database* - **PostgreSQL 17+** 
- *Analysis Tools/ IDE* - **DBeaver + VSCode**
- *Visualization & Publish to web* - **Power BI Desktop & Power BI Services** 
- *Version control & portfolio showcase* - **Git/ GitHub + LinkedIn** 
---
## 🕵️ Analysis

### 1. Customer Segmentation
[**🖥️ Query**](/Q1_Customer_Segmentation.sql)
```sql
WITH customer_ltv AS (
	SELECT ca.customerkey, ca.cleaned_name,
		sum(ca.total_net_revenue ) AS total_ltv
	FROM cohort_analysis ca
	GROUP BY ca.customerkey, ca.cleaned_name
	ORDER BY ca.customerkey
),
customer_segment AS (
	SELECT
		PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY total_ltv) AS ltv_25th_prcntile,
		PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY total_ltv) AS ltv_75th_prcntile
	FROM customer_ltv
),
segment_values AS (
	SELECT
      cl.*,
		CASE 
			WHEN cl.total_ltv < cs.ltv_25th_prcntile THEN '1 - Low Value'
			WHEN cl.total_ltv > cs.ltv_75th_prcntile THEN '3 - High Value'
			ELSE '2 - Mid Value'
		END AS customer_segment
	FROM customer_ltv cl, customer_segment cs
)
SELECT
   customer_segment,
	sum(total_ltv) AS total_ltv,
	count(customerkey) AS customer_count,
	sum(total_ltv) / count(customerkey) AS avg_ltv
FROM segment_values
GROUP BY customer_segment
ORDER BY customer_segment DESC
```

- Categorized customers based on total lifetime value (LTV)
- Assigned customers to High, Mid, and Low-value segments
- Calculated key metrics like total revenue

**📈 Visualization:**

<img src="../Resources/images/6.3_customer_segementation.png" alt="Customer Segmentation" width="50%">

**📊 Key Findings:**
- High-value segment (25% of customers) drives 66% of revenue ($135.4M)
- Mid-value segment (50% of customers) generates 32% of revenue ($66.6M)
- Low-value segment (25% of customers) accounts for 2% of revenue ($4.3M)

**🔍 Business Insights**
- High-Value (66% revenue): Offer premium membership program to 12,372 VIP customers, as losing one customer significantly impacts revenue
- Mid-Value (32% revenue): Create upgrade paths through personalized promotions, with potential $66.6M → $135.4M revenue opportunity
- Low-Value (2% revenue): Design re-engagement campaigns and price-sensitive promotions to increase purchase frequency
---
### 2. Customer Revenue by Cohort Year
[**🖥️ Query**](/Q2_Cohort_Analysis.sql)
```sql
SELECT 
	cohort_year,
	sum(total_net_revenue) AS total_revenue,
	count(DISTINCT customerkey) AS total_customers,
	sum(total_net_revenue) / count(DISTINCT customerkey) AS customer_revenue
FROM cohort_analysis
WHERE orderdate = first_purchase_date 
GROUP BY cohort_year
```

- Tracked revenue and customer count per cohorts
- Cohorts were grouped by year of first purchase
- Analyzed customer revenue at a cohort level

**📈 Visualization:**

> ⚠️ Note: This only includes 2 charts. 

Customer Revenue by Cohort (Adjusted for time in market) - First Purchase Date 

<img src="../Resources/images/5.2_customer_revenue_normalized.png" alt="Customer Revenue Normalized" width="50%">

Investigate Monthly Revenue & Customer Trends (3 Month Rolling Average)

<img src="../Resources/images/5.2_monthly_revenue_customers_3mo.png" alt="Monthly Revenue & CustomerTrends" width="50%">  

**📊 Key Findings:**  
- Customer revenue is declining, older cohorts (2016-2018) spent ~$2,800+, while 2024 cohort spending dropped to ~$1,970.  
- Revenue and customers peaked in 2022-2023, but both are now trending downward in 2024.  
- High volatility in revenue and customer count, with sharp drops in 2020 and 2024, signaling retention challenges.  

**🔍 Business Insights:**  
- Boost retention & re-engagement by targeting recent cohorts (2022-2024) with personalized offers to prevent churn.  
- Stabilize revenue fluctuations and introduce loyalty programs or subscriptions to ensure consistent spending.  
- Investigate cohort differences by applying successful strategies from high-spending cohorts (2016-2018) to newer ones.
---
### 3. Customer Retention
[**🖥️ Query**](/Q3_Retention_Analysis.sql)
```sql
WITH last_purchase AS (
	SELECT
		ca.customerkey, ca.cleaned_name, ca.orderdate AS last_purchase_date,
		ROW_NUMBER() OVER(PARTITION BY customerkey ORDER BY orderdate DESC) AS rn,
		ca.cohort_year, ca.first_purchase_date
	FROM cohort_analysis ca
),
churned_customers AS (
	SELECT
      customerkey, cleaned_name, cohort_year, last_purchase_date,
		CASE 
			WHEN last_purchase_date  < (SELECT max(orderdate) FROM sales) - INTERVAL '6 months' THEN 'Churned'
			ELSE 'Active'
		END AS customer_status
	FROM last_purchase 
	WHERE rn = 1 AND first_purchase_date < (SELECT max(orderdate) FROM sales) - INTERVAL '6 months'
)
SELECT
	cohort_year, customer_status,
	count(customerkey) AS num_customers,
	sum(count(customerkey)) OVER(PARTITION BY cohort_year) AS total_customers,
	round(count(customerkey) * 100 / sum(count(customerkey)) OVER(PARTITION BY cohort_year), 2) AS status_prctage
FROM churned_customers
GROUP BY cohort_year, customer_status 🛠
```

- Identified customers at risk of churning
- Analyzed last purchase patterns
- Calculated customer-specific metrics

**📈 Visualization:**

<img src="../Resources/images/7.3_customer_churn_cohort_year.png" alt="Customer Churn by Cohort Year" style="width: 50%; height: auto;">

**📊 Key Findings:**  
- Cohort churn stabilizes at ~90% after 2-3 years, indicating a predictable long-term retention pattern.  
- Retention rates are consistently low (8-10%) across all cohorts, suggesting retention issues are systemic rather than specific to certain years.  
- Newer cohorts (2022-2023) show similar churn trajectories, signaling that without intervention, future cohorts will follow the same pattern.  

**🔍 Business Insights:**  
- Strengthen early engagement strategies to target the first 1-2 years with onboarding incentives, loyalty rewards, and personalized offers to improve long-term retention.  
- Re-engage high-value churned customers by focusing on targeted win-back campaigns rather than broad retention efforts, as reactivating valuable users may yield higher ROI.  
- Predict & preempt churn risk and use customer-specific warning indicators to proactively intervene with at-risk users before they lapse.
---
## 🤺  Strategic Recommendations

1. **Customer Value Optimization** (Customer Segmentation)
   - Launch VIP program for 12,372 high-value customers (66% revenue)
   - Create personalized upgrade paths for mid-value segment ($66.6M → $135.4M opportunity)
   - Design price-sensitive promotions for low-value segment to increase purchase frequency

2. **Cohort Performance Strategy** (Customer Revenue by Cohort)
   - Target 2022-2024 cohorts with personalized re-engagement offers
   - Implement loyalty/subscription programs to stabilize revenue fluctuations
   - Apply successful strategies from high-spending 2016-2018 cohorts to newer customers

3. **Retention & Churn Prevention** (Customer Retention)
   - Strengthen first 1-2 year engagement with onboarding incentives and loyalty rewards
   - Focus on targeted win-back campaigns for high-value churned customers
   - Implement proactive intervention system for at-risk customers before they lapse

## 🙏 Acknowledgement

* Huge thanks to `Luke Barousse` & `Kelly Adams` for the dataset and guidance.! 🤗
* [SQL+ for Data Analytics](https://www.lukebarousse.com/int-sql) by `Luke Barousse`
---

## 👨‍💻 Author
**Thilina Perera | Data with TP**
```
📌 Data Science/ Data Analytics D-Technosavant
📌 Machine Learning, Deep Learning, LLM/LMM, NLP, and Automated Data Pipelines Inquisitive
``` 

[![LinkedIn](https://img.shields.io/badge/LinkedIn-%230077B5.svg?logo=linkedin&logoColor=white)](https://linkedin.com/in/thilina-perera-148aa934/)  [![TikTok](https://img.shields.io/badge/TikTok-%23000000.svg?logo=TikTok&logoColor=white)](https://tiktok.com/@data_with_tp) [![YouTube](https://img.shields.io/badge/YouTube-%23FF0000.svg?logo=YouTube&logoColor=white)](https://youtube.com/@Data_with_TP) [![email](https://img.shields.io/badge/Email-D14836?logo=gmail&logoColor=white)](mailto:kgttpereraqatar2022@gmail.com) 

## 🏆 License
    This project is licensed under the MIT License.
    Free to use and extend.
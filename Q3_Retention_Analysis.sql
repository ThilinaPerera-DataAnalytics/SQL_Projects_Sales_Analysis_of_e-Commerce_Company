WITH last_purchase AS (
	SELECT
		ca.customerkey,
		ca.cleaned_name,
		ca.orderdate AS last_purchase_date,
		ROW_NUMBER() OVER(
            PARTITION BY customerkey
            ORDER BY orderdate DESC
        ) AS rn,
		ca.cohort_year,
		ca.first_purchase_date
	FROM
		cohort_analysis ca
),
churned_customers AS (
	SELECT
		customerkey,
		cleaned_name,
		cohort_year,
		last_purchase_date,
		CASE
			WHEN last_purchase_date < (
				SELECT
					max(orderdate)
				FROM
					sales
			) - INTERVAL '6 months' THEN 'Churned'
			ELSE 'Active'
		END AS customer_status
	FROM
		last_purchase
	WHERE
		rn = 1
		AND first_purchase_date < (
			SELECT
				max(orderdate)
			FROM
				sales
		) - INTERVAL '6 months'
)
SELECT
	cohort_year,
	customer_status,
	count(customerkey) AS num_customers,
	sum(count(customerkey)) OVER(PARTITION BY cohort_year) AS total_customers,
	round(
        count(customerkey) * 100 / sum(count(customerkey)) OVER(PARTITION BY cohort_year),
        2
    ) AS status_prctage
FROM
	churned_customers
GROUP BY
	cohort_year,
	customer_status 🛠
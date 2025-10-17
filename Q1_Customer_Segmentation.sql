WITH customer_ltv AS (
	SELECT
		ca.customerkey,
		ca.cleaned_name,
		sum(ca.total_net_revenue) AS total_ltv
	FROM
		cohort_analysis ca
	GROUP BY
		ca.customerkey,
		ca.cleaned_name
	ORDER BY
		ca.customerkey
),
customer_segment AS (
	SELECT
		PERCENTILE_CONT(0.25) WITHIN GROUP (
		ORDER BY
			total_ltv
		) AS ltv_25th_prcntile,
		PERCENTILE_CONT(0.75) WITHIN GROUP (
		ORDER BY
			total_ltv
		) AS ltv_75th_prcntile
	FROM
		customer_ltv
),
segment_values AS (
	SELECT
		cl.*,
		CASE 
			WHEN cl.total_ltv < cs.ltv_25th_prcntile THEN '1 - Low Value'
			WHEN cl.total_ltv > cs.ltv_75th_prcntile THEN '3 - High Value'
			ELSE '2 - Mid Value'
		END AS customer_segment
	FROM
		customer_ltv cl,
		customer_segment cs
)
SELECT
	customer_segment,
	sum(total_ltv) AS total_ltv,
	count(customerkey) AS customer_count,
	sum(total_ltv) / count(customerkey) AS avg_ltv
FROM
	segment_values
GROUP BY
	customer_segment
ORDER BY
	customer_segment DESC
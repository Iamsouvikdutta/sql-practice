-- Monthly Customer Retention Rate
WITH cte1 AS (
SELECT DISTINCT customer_id, 
DATE_SUB(DATE(order_date), INTERVAL DAYOFMONTH(order_date)-1 DAY) AS order_month_date
FROM orders
WHERE order_status = "Delivered"
),cte2 AS (
SELECT DATE_FORMAT(c.order_month_date, "%Y-%m") AS yr_month, 
c.customer_id AS active_customer, 
t.customer_id AS retained_customer
FROM cte1 AS c
LEFT JOIN cte1 AS t 
ON c.customer_id = t.customer_id
AND c.order_month_date = DATE_ADD(t.order_month_date, INTERVAL 1 MONTH)
) 
SELECT yr_month, 
COUNT(DISTINCT active_customer) AS active_customers,
COUNT(DISTINCT retained_customer) AS retained_customers,
ROUND((COUNT(DISTINCT retained_customer) / COUNT(DISTINCT active_customer)) * 100, 2) AS retention_rate_pct
FROM cte2
GROUP BY yr_month
ORDER BY yr_month ASC;

-- Cohort Analysis (Signup Cohort)
-- Unable to understand question hence skipped

-- Identify Churned Customers
WITH cte1 AS(
SELECT customer_id, MAX(order_date) AS last_delivered_order,
DATEDIFF(CURDATE(),MAX(order_date)) AS days_since_last_order,
SUM(net_amount) AS CLTV 
FROM orders
WHERE order_status = "Delivered"
GROUP BY customer_id
) SELECT * 
FROM cte1 
WHERE days_since_last_order > 60;

-- Customer Health Segmentation
WITH cte1 AS(
SELECT customer_id, DATEDIFF(CURDATE(),MAX(order_date)) AS days_from_last_order,
COUNT(order_id) AS delivered_order, SUM(net_amount) AS revenue
FROM orders
WHERE order_status = "Delivered"
GROUP BY customer_id
) SELECT customer_id, delivered_order, revenue,
CASE WHEN days_from_last_order < 30 AND delivered_order > 5 THEN "Healthy"
WHEN days_from_last_order BETWEEN 30 AND 60 THEN "At risk"
ELSE "Churned" END AS health_status
FROM cte1;

-- Repeat Purchase Rate
WITH customer_order_counts AS (
SELECT customer_id,COUNT(order_id) AS total_orders
FROM orders
WHERE order_status = "Delivered"
GROUP BY customer_id
)
SELECT COUNT(customer_id) AS total_customer,
COUNT(CASE WHEN total_orders > 2 THEN customer_id END) AS repeat_customer,
ROUND((COUNT(CASE WHEN total_orders > 2 THEN customer_id END) / COUNT(customer_id)) * 100, 2) AS repeat_customer_pct
FROM customer_order_counts;

-- Cohort Revenue Trend
-- Did not understand the question

-- Churn Risk by City
WITH cte1 AS(
SELECT c.city_name, o.customer_id, DATEDIFF(CURDATE(),MAX(o.order_date)) AS days_from_last_order
FROM orders AS o
JOIN cities AS c
ON c.city_id = o.city_id
WHERE o.order_status = "Delivered"
GROUP BY c.city_name, o.customer_id
) SELECT city_name, COUNT(customer_id) AS total_customer,
COUNT(CASE WHEN days_from_last_order > 60 THEN customer_id END) AS churned_customer,
ROUND(COUNT(CASE WHEN days_from_last_order > 60 THEN customer_id END) / NULLIF(COUNT(customer_id),0),2) AS churned_pct
FROM cte1
GROUP BY city_name;

-- Executive Retention Dashboard
WITH cte1 AS(
SELECT customer_id, DATEDIFF(CURDATE(),MAX(order_date)) AS days_from_last_order
FROM orders
WHERE order_status = "Delivered"
GROUP BY customer_id
) SELECT COUNT(customer_id) As total_customers,
COUNT(CASE WHEN days_from_last_order <= 30 THEN customer_id END) AS active_customers,
COUNT(CASE WHEN days_from_last_order > 30 AND days_from_last_order <= 60 THEN customer_id END) AS at_risk,
COUNT(CASE WHEN days_from_last_order > 60 THEN customer_id END) AS churned,
ROUND(COUNT(CASE WHEN days_from_last_order <= 30 THEN customer_id END) / NULLIF(COUNT(customer_id),0),2) AS active_customers_pct,
ROUND(COUNT(CASE WHEN days_from_last_order > 30 AND days_from_last_order <= 60 THEN customer_id END) / NULLIF(COUNT(customer_id),0),2) AS at_risk_pct,
ROUND(COUNT(CASE WHEN days_from_last_order > 60 THEN customer_id END) / NULLIF(COUNT(customer_id),0),2) AS churned_pct
FROM cte1;
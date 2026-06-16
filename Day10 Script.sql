-- Build RFM Metrics for Every Customer
SELECT c.customer_name, DATEDIFF(CURDATE(),MAX(o.order_date)) AS recency,
COUNT(o.order_id) AS frequency, SUM(o.net_amount) as monetary
FROM orders AS o
JOIN customers AS c
ON o.customer_id = c.customer_id
WHERE o.order_status = "Delivered"
GROUP BY c.customer_name
ORDER BY recency, frequency DESC, monetary DESC;

-- Create RFM Scores (1–5)
WITH cte1 AS (
SELECT c.customer_name, DATEDIFF(CURDATE(),MAX(o.order_date)) AS recency,
COUNT(o.order_id) AS frequency, SUM(o.net_amount) as monetary
FROM orders AS o
JOIN customers AS c
ON o.customer_id = c.customer_id
WHERE o.order_status = "Delivered"
GROUP BY c.customer_name
ORDER BY recency, frequency DESC, monetary DESC
) SELECT customer_name, recency,
NTILE(5) OVER(ORDER BY recency ASC) AS recency_score,
frequency, NTILE(5) OVER(ORDER BY frequency DESC) AS frequency_score,
monetary, NTILE(5) OVER(ORDER BY monetary DESC) AS monetary_score,
(NTILE(5) OVER(ORDER BY recency DESC) + NTILE(5) OVER(ORDER BY frequency ASC) + NTILE(5) OVER(ORDER BY monetary ASC)) AS rfm_score
FROM cte1
ORDER BY rfm_score DESC;

-- Create Customer Segments Using RFM
WITH cte1 AS (
SELECT c.customer_name, DATEDIFF(CURDATE(),MAX(o.order_date)) AS recency,
COUNT(o.order_id) AS frequency, SUM(o.net_amount) as monetary
FROM orders AS o
JOIN customers AS c
ON o.customer_id = c.customer_id
WHERE o.order_status = "Delivered"
GROUP BY c.customer_name
ORDER BY recency, frequency DESC, monetary DESC
), cte2 AS (
SELECT customer_name, recency,
NTILE(5) OVER(ORDER BY recency ASC) AS recency_score,
frequency, NTILE(5) OVER(ORDER BY frequency DESC) AS frequency_score,
monetary, NTILE(5) OVER(ORDER BY monetary DESC) AS monetary_score,
(NTILE(5) OVER(ORDER BY recency DESC) + NTILE(5) OVER(ORDER BY frequency ASC) + NTILE(5) OVER(ORDER BY monetary ASC)) AS rfm_score
FROM cte1
ORDER BY rfm_score DESC
) SELECT customer_name, rfm_score,
CASE WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >=4 THEN "Champion"
WHEN recency_score >= 3 AND frequency_score >= 3 THEN "Loyal Customer"
WHEN recency_score = 5 AND frequency_score <= 2 THEN "New Customer"
WHEN recency_score <= 2 AND frequency_score >= 4 THEN "At Risk"
WHEN recency_score <= 2 AND frequency_score <= 4 THEN "Lost Customer"
ELSE "Potential Loyalists" END AS segement
FROM cte2;

-- Revenue Contribution by Customer Segment
WITH cte1 AS (
SELECT c.customer_name, DATEDIFF(CURDATE(),MAX(o.order_date)) AS recency,
COUNT(o.order_id) AS frequency, SUM(o.net_amount) as monetary
FROM orders AS o
JOIN customers AS c
ON o.customer_id = c.customer_id
WHERE o.order_status = "Delivered"
GROUP BY c.customer_name
ORDER BY recency, frequency DESC, monetary DESC
), cte2 AS (
SELECT customer_name, recency,
NTILE(5) OVER(ORDER BY recency ASC) AS recency_score,
frequency, NTILE(5) OVER(ORDER BY frequency DESC) AS frequency_score,
monetary, NTILE(5) OVER(ORDER BY monetary DESC) AS monetary_score,
(NTILE(5) OVER(ORDER BY recency DESC) + NTILE(5) OVER(ORDER BY frequency ASC) + NTILE(5) OVER(ORDER BY monetary ASC)) AS rfm_score
FROM cte1
ORDER BY rfm_score DESC
),cte3 AS (
SELECT customer_name, monetary,
CASE WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >=4 THEN "Champion"
WHEN recency_score >= 3 AND frequency_score >= 3 THEN "Loyal Customer"
WHEN recency_score = 5 AND frequency_score <= 2 THEN "New Customer"
WHEN recency_score <= 2 AND frequency_score >= 4 THEN "At Risk"
WHEN recency_score <= 2 AND frequency_score <= 4 THEN "Lost Customer"
ELSE "Potential Loyalists" END AS segement
FROM cte2
) SELECT segement,
COUNT(customer_name) AS total_customer,
ROUND(SUM(monetary),2) AS total_revenue,
ROUND(AVG(monetary),2) AS avg_revenue_per_customer,
ROUND((SUM(monetary) / SUM(SUM(monetary)) OVER()) * 100,2) AS revenue_contri_pct
FROM cte3
GROUP BY segement
ORDER BY total_revenue DESC;

-- Identify High-Value Customers at Risk
WITH cte1 AS (
SELECT c.customer_name, DATEDIFF(CURDATE(),MAX(o.order_date)) AS recency, MAX(o.order_date) AS last_order_date,
COUNT(o.order_id) AS frequency, SUM(o.net_amount) as monetary
FROM orders AS o
JOIN customers AS c
ON o.customer_id = c.customer_id
WHERE o.order_status = "Delivered"
GROUP BY c.customer_name
ORDER BY recency, frequency DESC, monetary DESC
),cte2 AS (SELECT customer_name, recency, last_order_date,
NTILE(5) OVER(ORDER BY recency ASC) AS recency_score,
frequency, NTILE(5) OVER(ORDER BY frequency DESC) AS frequency_score,
monetary, NTILE(5) OVER(ORDER BY monetary DESC) AS monetary_score,
(NTILE(5) OVER(ORDER BY recency DESC) + NTILE(5) OVER(ORDER BY frequency ASC) + NTILE(5) OVER(ORDER BY monetary ASC)) AS rfm_score
FROM cte1
ORDER BY rfm_score DESC
) SELECT customer_name, 
monetary AS revenue,
DATE(last_order_date) AS last_order_date,
recency as days_since_last_order
FROM cte2
WHERE monetary_score >=4
AND frequency_score >=4
AND recency_score <=2;

-- Customer Lifetime Value Segmentation
WITH cte1 AS(
SELECT customer_id, SUM(net_amount) AS CLV
FROM orders
WHERE order_status = "Delivered"
GROUP BY customer_id
), cte2 AS(
SELECT customer_id, CLV,
CASE WHEN CLV >= 30000 THEN "VIP"
WHEN CLV >= 15000 AND CLV <= 29999 THEN "High_value"
WHEN CLV >= 5000 AND CLV <= 14999 THEN "Medium_value"
ELSE "Low_value" END AS segement
FROM cte1
) SELECT segement,
COUNT(customer_id) AS total_customer,
SUM(CLV) AS total_revenue,
ROUND(SUM(CLV) / COUNT(customer_id),2) AS avg_revenue
FROM cte2
GROUP BY segement;

-- City-wise RFM Performance
WITH cte1 AS (
SELECT c.customer_name, o.city_id, DATEDIFF(CURDATE(),MAX(o.order_date)) AS recency,
COUNT(o.order_id) AS frequency, SUM(o.net_amount) as monetary
FROM orders AS o
JOIN customers AS c
ON o.customer_id = c.customer_id
WHERE o.order_status = "Delivered"
GROUP BY c.customer_name, o.city_id
ORDER BY recency, frequency DESC, monetary DESC
) SELECT c.city_name, ROUND(AVG(recency),2) AS avg_recency,
ROUND(AVG(frequency),2) AS avg_frequency,
ROUND(AVG(monetary),2) AS avg_monetary,
DENSE_RANK() OVER(ORDER BY AVG(monetary) DESC) AS monetary_rank
FROM cte1
JOIN cities AS c
ON cte1.city_id = c.city_id
GROUP BY c.city_name;

-- Executive Customer Dashboard
WITH cte1 AS (
SELECT c.customer_id,c.customer_name, 
DATEDIFF(CURDATE(), MAX(o.order_date)) AS recency,
COUNT(o.order_id) AS frequency, 
SUM(o.net_amount) AS monetary -- Changed net_amount to amount based on schema
FROM orders AS o
JOIN customers AS c ON o.customer_id = c.customer_id
WHERE o.order_status = "Delivered"
GROUP BY c.customer_id, c.customer_name
),cte2 AS (
SELECT customer_name, monetary,
NTILE(5) OVER(ORDER BY recency ASC) AS recency_score,
NTILE(5) OVER(ORDER BY frequency DESC) AS frequency_score,
NTILE(5) OVER(ORDER BY monetary DESC) AS monetary_score
FROM cte1
),cte3 AS (
SELECT customer_name, monetary,
CASE WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'Champion'
WHEN recency_score >= 3 AND frequency_score >= 3 THEN 'Loyal Customer'
WHEN recency_score = 5 AND frequency_score <= 2 THEN 'New Customer'
WHEN recency_score <= 2 AND frequency_score >= 4 THEN 'At Risk'
WHEN recency_score <= 2 AND frequency_score <= 4 THEN 'Lost Customer'
ELSE 'Potential Loyalists' 
END AS segment
FROM cte2
)SELECT 
COUNT(customer_name) AS total_customers,
COUNT(CASE WHEN segment = 'Champion' THEN 1 END) AS champions,
COUNT(CASE WHEN segment = 'Loyal Customer' THEN 1 END) AS loyal_customers,
COUNT(CASE WHEN segment = 'At Risk' THEN 1 END) AS at_risk_customers,
COUNT(CASE WHEN segment = 'Lost Customer' THEN 1 END) AS lost_customers,
ROUND(SUM(monetary), 2) AS total_revenue,
ROUND(SUM(CASE WHEN segment = 'Champion' THEN monetary ELSE 0 END), 2) AS revenue_from_champions,    
ROUND((SUM(CASE WHEN segment = 'Champion' THEN monetary ELSE 0 END) / NULLIF(SUM(monetary), 0)) * 100, 2) AS champion_revenue_pct,
ROUND(AVG(monetary), 2) AS average_customer_revenue
FROM cte3;

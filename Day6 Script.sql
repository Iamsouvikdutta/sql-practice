-- Find:monthly delivered revenue,cumulative running revenue over time

WITH monthly_revenue AS (
SELECT DATE_FORMAT(order_date, "%Y-%m") AS yr_month,
SUM(net_amount) AS monthly_revenue
FROM orders
WHERE order_status = "Delivered"
GROUP BY DATE_FORMAT(order_date, "%Y-%m")
ORDER BY DATE_FORMAT(order_date, "%Y-%m") ASC
) SELECT yr_month, monthly_revenue,
SUM(monthly_revenue) OVER(ORDER BY yr_month) AS cummulative_revenue
FROM monthly_revenue;

-- Calculate:monthly delivered revenue,rolling 3-month moving average
WITH monthly_revenue AS (
SELECT DATE_FORMAT(order_date, "%Y-%m") AS yr_month,
SUM(net_amount) AS monthly_revenue
FROM orders
WHERE order_status = "Delivered"
GROUP BY DATE_FORMAT(order_date, "%Y-%m")
ORDER BY DATE_FORMAT(order_date, "%Y-%m") ASC
)SELECT yr_month, monthly_revenue,
ROUND(AVG(monthly_revenue) OVER (ORDER BY yr_month ASC ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),2) AS last_3month_avg_revenue
FROM monthly_revenue;

-- Find cumulative delivered revenue growth for each city month-over-month.
WITH monthly_revenue AS (
SELECT c.city_name, DATE_FORMAT(o.order_date, "%Y-%m") AS yr_month,
SUM(o.net_amount) AS monthly_revenue
FROM orders AS o
JOIN cities AS c
ON o.city_id = c.city_id
WHERE order_status = "Delivered"
GROUP BY c.city_name, DATE_FORMAT(o.order_date, "%Y-%m")
ORDER BY c.city_name ASC, DATE_FORMAT(order_date, "%Y-%m") ASC
), cumulative_revenue AS (
SELECT city_name, yr_month, monthly_revenue,
SUM(monthly_revenue) OVER (PARTITION BY city_name ORDER BY yr_month ASC) AS cumulative_revenue
FROM monthly_revenue
GROUP BY city_name, yr_month
) SELECT city_name, yr_month, monthly_revenue, cumulative_revenue,
LAG(monthly_revenue,1,NULL) OVER (PARTITION BY city_name ORDER BY yr_month ASC) - monthly_revenue AS growth_degrowth_revenue
FROM cumulative_revenue;

-- Find:monthly delivered revenue,previous month revenue,MoM growth percentage

WITH monthly_revenue AS (
SELECT DATE_FORMAT(order_date, "%Y-%m") AS yr_month,
SUM(net_amount) AS monthly_revenue
FROM orders
WHERE order_status = "Delivered"
GROUP BY DATE_FORMAT(order_date, "%Y-%m")
ORDER BY DATE_FORMAT(order_date, "%Y-%m") ASC
), previous_month_revenue AS (
SELECT yr_month, monthly_revenue,
LAG(monthly_revenue,1,NULL) OVER (ORDER BY yr_month ASC) AS previous_month_revenue
FROM monthly_revenue
) SELECT yr_month, monthly_revenue, previous_month_revenue,
ROUND(((previous_month_revenue - monthly_revenue) / previous_month_revenue) * 2,2) AS growth_pct
FROM previous_month_revenue
GROUP BY yr_month;

-- For each customer:calculate cumulative delivered order count over time
SELECT customer_id, DATE(order_date) AS order_date, 
SUM(COUNT(order_date)) OVER (PARTITION BY customer_id ORDER BY DATE(order_date)) AS cumulative_order_count
FROM orders
WHERE order_status = "Delivered"
GROUP BY customer_id, DATE(order_date)
ORDER BY customer_id, DATE(order_date) ASC;


-- Find: daily delivered revenue,rolling 7-day moving average
WITH daily_revenue AS (
SELECT DATE(order_date) AS order_date, SUM(net_amount) AS daily_revenue
FROM orders
GROUP BY DATE(order_date)
ORDER BY DATE(order_date) ASC
) SELECT order_date, daily_revenue,
ROUND(AVG(daily_revenue) OVER (ORDER BY order_date ASC ROWS BETWEEN 6 PRECEDING AND CURRENT ROW),2) AS 7day_avg_revenue
FROM daily_revenue
GROUP BY order_date;

-- Find:category monthly revenue,previous month category revenue,monthly revenue difference
WITH monthly_revenue AS (
SELECT c.category_name, DATE_FORMAT(order_date,"%Y-%m") AS yr_month, SUM(oi.item_price * oi.quantity) AS monthly_revenue
FROM orders AS o
JOIN order_items AS oi
ON o.order_id = oi.order_id
JOIN products AS p
ON oi.product_id = p.product_id
JOIN categories AS c
ON p.category_id = c.category_id
WHERE o.order_status = "Delivered"
GROUP BY c.category_name, DATE_FORMAT(order_date,"%Y-%m")
ORDER BY c.category_name, DATE_FORMAT(order_date,"%Y-%m") ASC
)
SELECT category_name, yr_month, monthly_revenue,
LAG(monthly_revenue,1,NULL) OVER (PARTITION BY category_name ORDER BY yr_month ASC) AS previous_month_revenue,
monthly_revenue - LAG(monthly_revenue,1,NULL) OVER (PARTITION BY category_name ORDER BY yr_month ASC) AS revenue_difference
FROM monthly_revenue;

-- Find:campaign monthly delivered revenue,cumulative campaign revenue over time,campaign revenue rank month-wise
WITH campaign_revenue AS (
SELECT c.campaign_name, DATE_FORMAT(o.order_date,"%Y-%m") AS yr_month,
SUM(o.net_amount) AS monthly_campaign_revenue
FROM orders AS o
JOIN campaigns AS c
ON o.campaign_id = c.campaign_id
WHERE o.order_status = "Delivered"
GROUP BY c.campaign_name, DATE_FORMAT(o.order_date,"%Y-%m")
ORDER By c.campaign_name, DATE_FORMAT(o.order_date,"%Y-%m")
), cumulative_revenue AS (
SELECT campaign_name, yr_month, monthly_campaign_revenue,
SUM(monthly_campaign_revenue) OVER (PARTITION BY campaign_name ORDER BY yr_month ASC) AS cumulative_revenue
FROM campaign_revenue
) SELECT campaign_name, yr_month, monthly_campaign_revenue, cumulative_revenue,
DENSE_RANK() OVER (PARTITION BY campaign_name ORDER BY monthly_campaign_revenue DESC) AS revenue_rank
FROM cumulative_revenue;

-- Find:city-wise delivered revenue,total delivered orders,average delivered order value
SELECT c.city_name, COUNT(o.order_id) AS total_delivered_order,
ROUND(AVG(o.net_amount),0) AS avg_order_value
FROM orders AS o
JOIN cities AS c
ON o.city_id = c.city_id
WHERE o.order_status = "Delivered"
GROUP BY c.city_name
ORDER BY COUNT(o.order_id) DESC;

-- Segment customers based on delivered order count:
SELECT customer_id, COUNT(order_id) AS delivered_order,
SUM(net_amount) AS total_revenue, 
CASE WHEN COUNT(order_id) > 15 THEN "Power_user"
WHEN COUNT(order_id) >= 8 AND COUNT(order_id) <=15 THEN "Frequent"
WHEN COUNT(order_id) >= 3 AND COUNT(order_id) <=7 THEN "Moderate"
WHEN COUNT(order_id) < 3 THEN "Low_engagement" END AS customer_segment
FROM orders
WHERE order_status = "Delivered"
GROUP BY customer_id
ORDER BY COUNT(order_id) DESC;

-- Find top 5 categories by delivered revenue contribution.
WITH category_revenue AS (
SELECT c.category_name, SUM(oi.item_price * oi.quantity) AS category_revenue,
(SELECT SUM(oi.item_price * oi.quantity) FROM order_items AS oi JOIN orders as o ON oi.order_id = o.order_id JOIN products AS p
ON oi.product_id = p.product_id JOIN categories AS c ON p.category_id = c.category_id WHERE o.order_status ="Delivered") AS total_revenue
FROM order_items AS oi 
JOIN orders as o 
ON oi.order_id = o.order_id 
JOIN products AS p
ON oi.product_id = p.product_id 
JOIN categories AS c 
ON p.category_id = c.category_id 
WHERE o.order_status ="Delivered"
GROUP BY c.category_name
) SELECT category_name, category_revenue,
ROUND((category_revenue / total_revenue) * 100,2) AS contribution_pct
FROM category_revenue
ORDER BY (category_revenue / total_revenue) * 100 DESC;

-- Find:total campaign orders,delivered orders,cancellation percentage,conversion percentage
WITH campaign_total_order AS (
SELECT campaign_id, COUNT(order_id) AS total_order
FROM orders
GROUP BY campaign_id
ORDER BY COUNT(order_id) DESC
), delivered_order AS (
SELECT campaign_id, COUNT(order_id) AS delivered_order
FROM orders
WHERE order_status = "Delivered"
GROUP BY campaign_id
) SELECT c.campaign_name, d.delivered_order, (t.total_order - d.delivered_order) AS cancelled_order,
ROUND((d.delivered_order / t.total_order) * 100,2) AS coversion_pct
FROM campaigns AS c
JOIN campaign_total_order AS t
ON c.campaign_id = t.campaign_id
JOIN delivered_order AS d
ON c.campaign_id = d.campaign_id;

-- Find:month-wise delivered revenue,previous month revenue,revenue growth percentage
WITH monthly_revenue AS (
SELECT DATE_FORMAT(order_date,"%Y-%m") AS Yr_month, SUM(net_amount) AS monthly_revenue,
LAG(SUM(net_amount),1,NULL) OVER(ORDER BY DATE_FORMAT(order_date, "%Y-%m")) AS previous_month_revenue
FROM orders
WHERE order_status = "Delivered"
GROUP BY DATE_FORMAT(order_date,"%Y-%m")
ORDER BY DATE_FORMAT(order_date, "%Y-%m")
) SELECT yr_month, monthly_revenue, previous_month_revenue,
ROUND(((monthly_revenue - previous_month_revenue) / previous_month_revenue) * 100,2) AS growth_pct
FROM monthly_revenue;

-- Find top 3 products inside each category based on delivered revenue.
WITH category_revenue AS (
SELECT c.category_name, p.product_name, SUM((oi.item_price * oi.quantity)) AS product_revenue
FROM order_items AS oi
JOIN orders AS o
ON oi.order_id = o.order_id
JOIN products AS p
ON p.product_id = oi.product_id
JOIN categories AS c
ON c.category_id = p.category_id
WHERE o.order_status = "Delivered"
GROUP BY c.category_name, p.product_name
ORDER BY c.category_name ASC, SUM((oi.item_price * oi.quantity)) DESC
), product_rank AS ( SELECT category_name, product_name, product_revenue,
DENSE_RANK() OVER(PARTITION BY category_name ORDER BY product_revenue DESC) AS revenue_rank
FROM category_revenue
) SELECT * 
FROM product_rank
WHERE revenue_rank <=3;

-- Find:city monthly revenue,cumulative city revenue over time
SELECT c.city_name, DATE_FORMAT(o.order_date,"%Y-%m") AS yr_month, SUM(o.net_amount) AS city_revenue,
SUM(SUM(o.net_amount)) OVER(PARTITION BY c.city_name ORDER BY DATE_FORMAT(o.order_date,"%Y-%m")) AS cumulative_revenue
FROM orders AS o
JOIN cities AS c
ON o.city_id = c.city_id
WHERE o.order_status = "Delivered"
GROUP BY c.city_name, DATE_FORMAT(o.order_date,"%Y-%m")
ORDER BY c.city_name ASC, DATE_FORMAT(o.order_date,"%Y-%m");

-- Find:customer monthly revenue,previous month spending,spending difference
WITH customer_spend AS (
SELECT customer_id, DATE_FORMAT(order_date,"%Y-%m") AS yr_month,
SUM(net_amount) AS cur_month_spend,
LAG(SUM(net_amount),1,NULL) OVER(PARTITION BY customer_id ORDER BY DATE_FORMAT(order_Date,"%Y-%m")) AS pre_month_spend
FROM orders
WHERE order_status = "Delivered"
GROUP BY customer_id, DATE_FORMAT(order_date,"%Y-%m")
ORDER BY customer_id, DATE_FORMAT(order_date,"%Y-%m") ASC
) SELECT customer_id, yr_month, cur_month_spend, pre_month_spend,
(cur_month_spend - pre_month_spend) AS spend_difference
FROM customer_spend;

-- Rank payment gateways based on payment success percentage.
WITH success_payment AS (
SELECT payment_gateway, COUNT(payment_id) AS success_payment
FROM payments 
WHERE payment_status = "Success"
GROUP BY payment_gateway
), total_payment AS (
SELECT payment_gateway, COUNT(payment_id) AS total_payment
FROM payments 
GROUP BY payment_gateway
)SELECT s.payment_gateway,
ROUND((s.success_payment / t.total_payment) * 100,2) AS success_pct,
DENSE_RANK() OVER(ORDER BY ROUND((s.success_payment / t.total_payment) * 100,2) DESC) AS gateway_rank
FROM success_payment AS s
JOIN total_payment AS t
ON s.payment_gateway = t.payment_gateway;

-- For each month:rank campaigns based on delivered revenue.
SELECT DATE_FORMAT(o.order_date,"%Y-%m") AS yr_month, c.campaign_name,
SUM(o.net_amount) AS campaign_revenue,
DENSE_RANK() OVER( PARTITION BY DATE_FORMAT(o.order_date,"%Y-%m") ORDER BY SUM(o.net_amount) DESC) AS campaign_rank
FROM orders AS o
JOIN campaigns as c
ON o.campaign_id = c.campaign_id
WHERE o.order_status = "Delivered"
GROUP BY DATE_FORMAT(o.order_date,"%Y-%m"), c.campaign_name
ORDER BY DATE_FORMAT(o.order_date,"%Y-%m") ASC;

-- Find customers who:generated above-average delivered revenue,but placed no delivered orders in last 60 days
WITH customer_revenue AS (
SELECT customer_id, SUM(net_amount) AS revenue, MAX(order_date) AS last_order_date, DATEDIFF(CURDATE(),MAX(order_date)) AS days_gap
FROM orders
WHERE order_status ="Delivered"
GROUP BY customer_id
ORDER BY SUM(net_amount) DESC
), avg_revenue AS (
SELECT AVG(revenue) AS avg_revenue
FROM customer_revenue
) SELECT customer_id, revenue, DATE(last_order_date) AS last_order_date, days_gap
FROM customer_revenue 
CROSS JOIN avg_revenue
WHERE revenue > avg_revenue
AND days_gap > 60;

-- Find cities where:average delivery time is above platform average but delivered revenue is below platform average
WITH avg_table AS (
SELECT city_id, 
ROUND(AVG(delivery_time_mins),2) AS avg_delivery_time,
SUM(net_amount) AS delivered_revenue
FROM orders
WHERE order_status = "Delivered"
GROUP BY city_id
), platform_avg AS(
SELECT ROUND(AVG(avg_delivery_time),2) AS platform_avg_delivery_time,
ROUND(AVG(delivered_revenue),2) AS platform_avg_delivered_revenue
FROM avg_table
), final_table AS( SELECT a.city_id, a.avg_delivery_time, a.delivered_revenue, p.platform_avg_delivery_time, p.platform_avg_delivered_revenue
FROM avg_table AS a
CROSS JOIN platform_avg AS p
) SELECT c.city_name, f.avg_delivery_time, f.delivered_revenue AS city_revenue
FROM final_table AS f
JOIN cities AS c
ON f.city_id = c.city_id
WHERE f.avg_delivery_time > f.platform_avg_delivery_time 
AND f.delivered_revenue < f.platform_avg_delivered_revenue;

-- Find categories where:top product contributes more than 40% of category revenue
WITH category_revenue AS (
SELECT c.category_id, c.category_name, SUM(oi.item_price * oi.quantity) AS category_revenue
FROM order_items AS oi
JOIN orders AS o
ON oi.order_id= o.order_id
JOIN products AS p
ON oi.product_id = p.product_id
JOIN categories AS c
ON c.category_id = p.category_id
WHERE o.order_status = "Delivered"
GROUP BY c.category_id, c.category_name
), product_revenue AS (
SELECT p.product_name, p.category_id, SUM(oi.item_price * oi.quantity) AS product_revenue
FROM order_items AS oi
JOIN orders AS o
ON oi.order_id = o.order_id
JOIN products AS p
ON oi.product_id = p.product_id
JOIN categories AS c
ON c.category_id = p.category_id
GROUP BY p.product_name, c.category_id
) SELECT cr.category_name, pr.product_name AS top_product, pr.product_revenue, cr.category_revenue,
ROUND((pr.product_revenue / cr.category_revenue) * 100,2) AS contribution_pct
FROM category_revenue AS cr
JOIN product_revenue AS pr
ON cr.category_id = pr.category_id
WHERE (pr.product_revenue / cr.category_revenue) * 100 > 40.00;

-- Find months where:revenue declined compared to previous monthBUT:order volume increased
WITH revenue AS (
SELECT DATE_FORMAT(order_date,"%Y-%m") AS yr_month, SUM(net_amount) AS revenue,
LAG(SUM(net_amount),1,NULL) OVER (ORDER BY DATE_FORMAT(order_date,"%Y-%m")) AS previous_month_revenue
FROM orders
WHERE order_status = "Delivered"
GROUP BY DATE_FORMAT(order_date,"%Y-%m")
ORDER BY DATE_FORMAT(order_date,"%Y-%m")
), order_volume AS (
SELECT DATE_FORMAT(order_date,"%Y-%m") AS yr_month, COUNT(order_id) AS orders,
LAG(COUNT(order_id),1,NULL) OVER(ORDER BY DATE_FORMAT(order_date,"%Y-%m")) AS previous_orders
FROM orders
WHERE order_status = "Delivered"
GROUP BY DATE_FORMAT(order_date,"%Y-%m")
ORDER BY DATE_FORMAT(order_date,"%Y-%m")
) SELECT r.yr_month, r.revenue, r.previous_month_revenue, ov.orders, ov.previous_orders
FROM revenue AS r
JOIN order_volume AS ov
ON r.yr_month = ov.yr_month
WHERE r.revenue < r.previous_month_revenue
AND ov.orders > ov.orders;


-- Create one query returning:For each month:total revenue,delivered orders,unique customers,average order value,cancellation rate
WITH cte1 AS (SELECT DATE_FORMAT(order_date,"%Y-%m") AS yr_month, 
SUM(net_amount) AS total_revenue,
COUNT(order_id) AS delivered_orders,
COUNT(DISTINCT customer_id) AS unique_customers,
ROUND(AVG(net_amount),2) AS avg_order_value
FROM orders
WHERE order_status = "Delivered"
GROUP BY DATE_FORMAT(order_date,"%Y-%m")
ORDER BY DATE_FORMAT(order_date,"%Y-%m")
), cte2 AS (
SELECT DATE_FORMAT(order_date,"%Y-%m") AS yr_month,COUNT(order_id) AS total_orders,
(SELECT COUNT(order_id) FROM orders WHERE order_status = "Cancelled") AS cancelled_orders,
ROUND(((SELECT COUNT(order_id) FROM orders WHERE order_status = "Cancelled") / COUNT(order_id)),2) AS cancellation_rate
FROM orders
GROUP BY DATE_FORMAT(order_date,"%Y-%m")
ORDER BY DATE_FORMAT(order_date,"%Y-%m")
) SELECT cte1.yr_month, cte1.total_revenue, cte1.delivered_orders, cte1.unique_customers, cte1.avg_order_value,
cte2.cancellation_rate
FROM cte1
JOIN cte2
ON cte1.yr_month = cte2.yr_month;

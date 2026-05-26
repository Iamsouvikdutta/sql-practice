-- Find the top 5 revenue-generating customers inside each city.
With customer_revenue AS (
SELECT c.city_name, o.customer_id, SUM(o.net_amount) AS total_revenue
FROM orders as o
JOIN cities as c
ON o.city_id = c.city_id
WHERE o.order_status = "Delivered"
GROUP BY c.city_name, o.customer_id
), customer_rank AS (
SELECT city_name, customer_id, total_revenue,
DENSE_RANK() OVER (PARTITION BY city_name ORDER BY total_revenue DESC) AS revenue_rank
FROM customer_revenue
ORDER BY city_name ASC
) SELECT city_name, customer_id, total_revenue, revenue_rank
FROM customer_rank
WHERE revenue_rank <=5;

-- Find the most ordered product inside each category based on total quantity sold.
With order_quantity AS (
SELECT c.category_name, p.product_name, SUM(oi.quantity) AS total_quantity_sold
FROM order_items as oi
JOIN orders AS o
ON oi.order_id = o.order_id
JOIN products AS p
ON oi.product_id = p.product_id
JOIN categories AS c
ON p.category_id = c.category_id
WHERE o.order_status = "Delivered"
GROUP BY c.category_name, p.product_name
ORDER BY c.category_name ASC
), product_rank AS (
SELECT category_name, product_name, total_quantity_sold,
DENSE_RANK() OVER (PARTITION BY category_name ORDER BY total_quantity_sold DESC) AS product_rank
FROM order_quantity
) SELECT * 
FROM product_rank
WHERE product_rank =1;

-- Rank campaigns based on delivered revenue contribution.
SELECT c.campaign_name, SUM(o.net_amount) AS campaign_revenue,
RANK() OVER (ORDER BY SUM(o.net_amount) DESC) AS revenue_rank
FROM orders AS o
JOIN campaigns AS c
ON o.campaign_id = c.campaign_id
WHERE o.order_status = "Delivered"
GROUP BY c.campaign_name
ORDER BY SUM(o.net_amount) DESC;

-- Find the top 3 fastest delivery cities based on average delivery time.
WITH delivery_time AS (
SELECT c.city_name, AVG(o.delivery_time_mins) AS avg_delivery_time
FROM orders AS o
JOIN cities AS c
ON o.city_id = c.city_id
WHERE o.order_status = "Delivered"
GROUP BY c.city_name
), delivery_rank AS (
SELECT city_name, avg_delivery_time, DENSE_RANK() OVER (ORDER BY avg_delivery_time ASC) AS delivery_rank
FROM delivery_time
) SELECT * FROM delivery_rank WHERE delivery_rank <=3 ORDER BY delivery_rank ASC;

-- For each customer:calculate month-wise revenue,assign spending rank month-wise
SELECT customer_id, DATE_FORMAT(order_date,"%Y-%m") AS "Year_month", 
SUM(net_amount) AS monthly_revenue,
DENSE_RANK() OVER (PARTITION BY customer_id ORDER BY SUM(net_amount) DESC) AS revenue_rank
FROM orders
WHERE order_status = "Delivered"
GROUP BY customer_id, DATE_FORMAT(order_date, "%Y-%m")
ORDER BY customer_id, SUM(net_amount) DESC,
DENSE_RANK() OVER (PARTITION BY customer_id ORDER BY SUM(net_amount) DESC) ASC;

-- Find the highest revenue-generating product for each month.
WITH product_revenue AS (
SELECT DATE_FORMAT(o.order_date, "%Y-%m") AS "Yr_Month", p.product_name,
SUM(oi.item_price * oi.quantity) AS product_revenue
FROM orders AS o
JOIN order_items AS oi
ON o.order_id = oi.order_id
JOIN products as P
ON p.product_id = oi.product_id
WHERE o.order_status = "Delivered"
GROUP BY DATE_FORMAT(o.order_date,"%Y-%m"), p.product_name
), revenue_rank AS (
SELECT Yr_Month, product_name, product_revenue,
DENSE_RANK() OVER ( PARTITION BY Yr_month ORDER BY product_revenue DESC) AS revenue_rank
FROM product_revenue
GROUP BY Yr_Month, product_name
) SELECT * FROM revenue_rank
WHERE revenue_rank = 1;

-- Rank payment gateways based on payment success percentage.
WITH gateway_payment AS (
SELECT p.payment_gateway, COUNT(p.payment_id) AS total_payment,
COUNT(CASE WHEN p.payment_status = "Success" THEN p.payment_id END) AS success_payment
FROM payments as p
JOIN orders as o
ON p.order_id = o.order_id
WHERE o.order_status = "Delivered"
GROUP BY p.payment_gateway
), success_pct AS (
SELECT payment_gateway, total_payment, success_payment,
(success_payment / total_payment) * 100 AS success_pct
FROM gateway_payment
) SELECT *,
DENSE_RANK() OVER (ORDER BY success_pct DESC) AS success_rank
FROM success_pct
ORDER BY success_pct DESC;

-- Rank categories based on percentage contribution to total platform revenue.
With product_revenue AS (
SELECT p.product_id, SUM(oi.item_price * oi.quantity) AS product_revenue
FROM products AS p
JOIN order_items AS oi
ON p.product_id = oi.product_id
JOIN orders AS o
ON o.order_id = oi.order_id
WHERE o.order_status = "Delivered"
GROUP BY p.product_id
), category_revenue AS (
SELECT c.category_name, SUM(product_revenue) AS category_revenue,
(SELECT SUM(product_revenue) FROM product_revenue) AS total_revenue
FROM product_revenue
JOIN products AS p
ON product_revenue.product_id = p.product_id
JOIN categories AS c
ON c.category_id = p.category_id
GROUP BY c.category_name
), revenue_pct AS (
SELECT category_name, category_revenue, 
ROUND((category_revenue / total_revenue) * 100,2) AS contribution_pct
FROM category_revenue
GROUP BY category_name
) SELECT *,
DENSE_RANK() OVER (ORDER BY contribution_pct DESC) AS contribution_rank
FROM revenue_pct
ORDER BY DENSE_RANK() OVER (ORDER BY contribution_pct DESC);

-- Rank customers inside each retention tier based on revenue.
WITH retention_tier AS (
SELECT customer_id,
CASE WHEN COUNT(order_id) > 10 THEN "Loyal"
WHEN COUNT(order_id) >= 5 AND COUNT(order_id) <= 10 THEN "Regular"
WHEN COUNT(order_id) < 5 THEN "Risk" END AS retention_tier,
SUM(net_amount) AS total_revenue
FROM orders
WHERE order_status = "Delivered"
GROUP BY customer_id
) SELECT customer_id, retention_tier, total_revenue,
DENSE_RANK() OVER (PARTITION BY retention_tier ORDER BY total_revenue DESC) AS retention_rank
FROM retention_tier
ORDER BY retention_tier ASC,
DENSE_RANK() OVER (PARTITION BY retention_tier ORDER BY total_revenue DESC);

-- Find months ranked by month-over-month revenue growth percentage.
WITH previous_month_revenue AS (
SELECT DATE_FORMAT(order_date, "%Y-%m") AS "Yr_month",
SUM(net_amount) AS month_revenue,
LAG(SUM(net_amount),1,NULL) OVER (ORDER BY DATE_FORMAT(order_date,"%Y-%m")) AS previous_month_revenue
FROM orders
WHERE order_status = "Delivered"
GROUP BY DATE_FORMAT(order_date,"%Y-%m")
ORDER BY DATE_FORMAT(order_date, "%Y-%m") ASC
), growth_pct AS (
SELECT Yr_month, month_revenue, previous_month_revenue,
ROUND(((month_revenue - previous_month_revenue) / previous_month_revenue ) * 100,2) AS growth_pct
FROM previous_month_revenue
) SELECT *,
DENSE_RANK() OVER (ORDER BY growth_pct DESC) AS growth_rank
FROM growth_pct
ORDER BY DENSE_RANK() OVER (ORDER BY growth_pct DESC);


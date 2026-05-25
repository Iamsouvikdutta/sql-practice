-- Customers Above Overall AOV
SELECT customer_id,
ROUND(AVG(net_amount), 2) AS customer_avg_order_value,
(SELECT ROUND(AVG(net_amount), 2)FROM orders WHERE order_status = 'Delivered') AS overall_platform_avg
FROM orders
WHERE order_status = 'Delivered'
GROUP BY customer_id
HAVING AVG(net_amount) >(SELECT AVG(net_amount)FROM orders WHERE order_status = 'Delivered')
ORDER BY customer_avg_order_value DESC;

-- Top Revenue Product in Each Category
WITH product_revenue AS (
SELECT p.product_id, p.product_name,p.category_id,
ROUND(SUM(oi.quantity * oi.item_price), 2) AS product_revenue
FROM products AS p
JOIN order_items AS oi
ON p.product_id = oi.product_id
JOIN orders AS o
ON oi.order_id = o.order_id
WHERE o.order_status = 'Delivered'
GROUP BY p.product_id,p.product_name,p.category_id
),ranked_products AS (SELECT c.category_name,pr.product_name,pr.product_revenue,
DENSE_RANK() OVER (PARTITION BY c.category_name ORDER BY pr.product_revenue DESC) AS revenue_rank
FROM product_revenue AS pr
JOIN categories AS c
ON pr.category_id = c.category_id
)SELECT category_name,product_name,product_revenue
FROM ranked_products
WHERE revenue_rank = 1
ORDER BY product_revenue DESC;

-- Cities Performing Above Platform Average Revenue
WITH city_revenue AS (SELECT c.city_id,c.city_name,
ROUND(SUM(o.net_amount), 2) AS city_revenue
FROM cities AS c
JOIN orders AS o
ON c.city_id = o.city_id
WHERE o.order_status = 'Delivered'
GROUP BY c.city_id,c.city_name
),
platform_avg_city_revenue AS (
SELECT ROUND(AVG(city_revenue), 2) AS avg_city_revenue
FROM city_revenue
)SELECT cr.city_name,cr.city_revenue,pacr.avg_city_revenue AS platform_avg_city_revenue
FROM city_revenue AS cr
CROSS JOIN platform_avg_city_revenue AS pacr
WHERE cr.city_revenue > pacr.avg_city_revenue
ORDER BY cr.city_revenue DESC;

-- Repeat Customers Analysis
WITH customer_orders AS 
(SELECT customer_id,COUNT(order_id) AS total_orders
FROM orders
WHERE order_status = 'Delivered'
GROUP BY customer_id
)SELECT customer_id,total_orders,
(SELECT ROUND(AVG(total_orders), 2) FROM customer_orders) AS avg_orders_platform
FROM customer_orders
WHERE total_orders >(SELECT AVG(total_orders)FROM customer_orders
)ORDER BY total_orders DESC;

-- Products Contributing More Than 20% Of Category Revenue
WITH product_revenue AS (
SELECT p.category_id,p.product_id,p.product_name,
SUM(oi.quantity * oi.item_price) AS product_revenue
FROM products AS p
JOIN order_items AS oi
ON p.product_id = oi.product_id
JOIN orders AS o
ON oi.order_id = o.order_id
WHERE o.order_status = 'Delivered'
GROUP BY p.category_id,p.product_id,p.product_name
),category_revenue AS (
SELECT category_id,
SUM(product_revenue) AS category_revenue
FROM product_revenue
GROUP BY category_id
)
SELECT c.category_name,pr.product_name,
ROUND(pr.product_revenue, 2) AS product_revenue,
ROUND(cr.category_revenue, 2) AS category_revenue,
ROUND((pr.product_revenue / cr.category_revenue) * 100,2) AS contribution_pct
FROM product_revenue AS pr
JOIN category_revenue AS cr
ON pr.category_id = cr.category_id
JOIN categories AS c
ON pr.category_id = c.category_id
WHERE (pr.product_revenue / cr.category_revenue) * 100 > 20
ORDER BY contribution_pct DESC;

-- Months Above Average Monthly Revenue
WITH monthly_revenue AS (
SELECT DATE_FORMAT(order_date, '%Y-%m') AS month_year,
ROUND(SUM(net_amount), 2) AS monthly_revenue
FROM orders
WHERE order_status = 'Delivered'
GROUP BY DATE_FORMAT(order_date, '%Y-%m')
),avg_monthly_revenue AS (
SELECT ROUND(AVG(monthly_revenue), 2) AS avg_platform_monthly_revenue
FROM monthly_revenue
)SELECT mr.month_year,mr.monthly_revenue,amr.avg_platform_monthly_revenue
FROM monthly_revenue AS mr
CROSS JOIN avg_monthly_revenue AS amr
WHERE mr.monthly_revenue > amr.avg_platform_monthly_revenue
ORDER BY mr.month_year;

-- Inactive High-Value Customers
WITH customer_revenue AS (
SELECT customer_id,
ROUND(SUM(net_amount), 2) AS total_revenue,
MAX(order_date) AS last_order_date
FROM orders
WHERE order_status = 'Delivered'
GROUP BY customer_id
),avg_customer_revenue AS (
SELECT ROUND(AVG(total_revenue), 2) AS avg_platform_customer_revenue
FROM customer_revenue
)
SELECT cr.customer_id,cr.total_revenue,cr.last_order_date
FROM customer_revenue AS cr
CROSS JOIN avg_customer_revenue AS acr
WHERE cr.total_revenue > acr.avg_platform_customer_revenue
AND DATEDIFF(CURDATE(), cr.last_order_date) > 60
ORDER BY cr.total_revenue DESC;

-- Campaigns With Better Than Average Conversion
WITH campaign_conversion AS (
SELECT c.campaign_id,c.campaign_name,
COUNT(o.order_id) AS total_orders,
COUNT(CASE WHEN o.order_status = 'Delivered'THEN o.order_id END) AS delivered_orders,
ROUND((COUNT(CASE WHEN o.order_status = 'Delivered'THEN o.order_id END) * 100.0) / COUNT(o.order_id),2) AS conversion_rate
FROM campaigns AS c
JOIN orders AS o
ON c.campaign_id = o.campaign_id
GROUP BY c.campaign_id,c.campaign_name
),
avg_conversion AS (
SELECT ROUND(AVG(conversion_rate), 2) AS avg_conversion_rate
FROM campaign_conversion
)
SELECT cc.campaign_name,cc.delivered_orders,cc.total_orders,cc.conversion_rate
FROM campaign_conversion AS cc
CROSS JOIN avg_conversion AS ac
WHERE cc.conversion_rate > ac.avg_conversion_rate
ORDER BY cc.conversion_rate DESC;
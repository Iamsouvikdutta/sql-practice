-- Build the platform funnel:
WITH platform_metrics AS (
SELECT COUNT(DISTINCT s.customer_id) AS signup_customers,
COUNT(s.session_id) AS total_session,
(SELECT COUNT(DISTINCT o.order_id) FROM orders AS o JOIN customer_sessions AS c ON o.customer_id = c.customer_id) AS total_orders,
(SELECT COUNT(p.payment_id) FROM payments AS p JOIN orders AS o ON p.order_id = o.order_id WHERE p.payment_status = "Success") AS success_payments,
(SELECT COUNT(DISTINCT order_id) FROM orders WHERE order_status = "Delivered") AS total_delivered_order
FROM customer_sessions AS s
) SELECT 'signup_customers' AS metric_name, signup_customers AS metric_value FROM platform_metrics
UNION ALL
SELECT 'total_session', total_session FROM platform_metrics
UNION ALL
SELECT 'total_orders', total_orders FROM platform_metrics
UNION ALL 
SELECT 'success_payments', success_payments FROM platform_metrics
UNION ALL
SELECT 'total_delivered_order', total_delivered_order FROM platform_metrics;

-- For each city calculate:Customers with session,Customers placing orders,Order conversion %
WITH CTE1 AS (
SELECT c.city_name, COUNT(s.customer_id) AS session_customer
FROM customer_sessions AS s
JOIN customers AS cc
ON s.customer_id = cc.customer_id
JOIN cities AS c
ON c.city_id = cc.city_id
GROUP BY c.city_name
), cte2 AS (
SELECT c.city_name, COUNT(o.order_id) AS total_order,
COUNT(DISTINCT o.customer_id) AS ordering_customer
FROM orders AS o
JOIN cities AS c
ON o.city_id = c.city_id
GROUP BY c.city_name
) SELECT cte1.city_name, cte1.session_customer, cte2.ordering_customer,
ROUND((cte2.ordering_customer / cte1.session_customer) *100,2) AS conversion_pct
FROM cte1 
JOIN cte2
ON cte1.city_name = cte2.city_name;

-- For every campaign calculate:Orders generated,Successful payments,Delivered orders,Payment conversion %,Delivery conversion %
WITH cte1 AS (
SELECT c.campaign_name, COUNT(o.order_id) AS orders
FROM orders AS o
JOIN campaigns AS c
ON c.campaign_id = o.campaign_id
GROUP BY c.campaign_name
), cte2 AS (
SELECT c.campaign_name, COUNT(p.payment_id) AS total_payments,
COUNT(CASE WHEN p.payment_status = "Success" THEN p.payment_id END) AS success_payment
FROM payments AS p
JOIN orders AS o
ON p.order_id = o.order_id
JOIN campaigns AS c
ON c.campaign_id = o.campaign_id
GROUP BY c.campaign_name
), cte3 AS (
SELECT c.campaign_name, COUNT(o.order_id) AS total_order,
COUNT(CASE WHEN o.order_status = "Delivered" THEN o.order_id END) AS delivered_order
FROM orders AS o
JOIN campaigns AS c
ON o.campaign_id = c.campaign_id
GROUP BY c.campaign_name
) SELECT cte1.campaign_name, cte1.orders, cte2.success_payment, cte3.delivered_order,
ROUND((cte2.success_payment / cte3.total_order) *100,2) AS payment_conversion_pct,
ROUND((cte3.delivered_order / cte3.total_order) *100,2) AS delivery_conversion_pct
FROM cte1 
JOIN cte2
ON cte1.campaign_name = cte2.campaign_name
JOIN cte3
ON cte2.campaign_name = cte3.campaign_name;

-- For every month calculate:Sessions,Ordering customers,Conversion %
WITH MonthlySessions AS (
SELECT DATE_FORMAT(session_start, "%Y-%m") AS yr_month,COUNT(DISTINCT session_id) AS total_sessions
FROM customer_sessions
GROUP BY DATE_FORMAT(session_start, "%Y-%m")
),
MonthlyOrders AS (
SELECT DATE_FORMAT(order_date, "%Y-%m") AS yr_month,COUNT(DISTINCT customer_id) AS unique_ordering_customers,
COUNT(order_id) AS total_orders
FROM orders
WHERE order_status = "Delivered"
GROUP BY DATE_FORMAT(order_date, "%Y-%m")
)
SELECT s.yr_month,s.total_sessions AS sessions,
COALESCE(o.unique_ordering_customers, 0) AS ordering_customers,
ROUND((o.unique_ordering_customers / o.total_orders) *100,2) AS conversion_pct
FROM MonthlySessions AS s
LEFT JOIN MonthlyOrders AS o ON s.yr_month = o.yr_month
ORDER BY s.yr_month ASC;

-- For each category calculate:Total ordered quantity,Delivered quantity,Fulfillment rate %
WITH cte1 AS (
SELECT p.category_id, SUM(oi.quantity) AS ordered_quantity
FROM order_items AS oi
JOIN products AS p
ON oi.product_id = p.product_id
GROUP BY p.category_id
), cte2 AS (
SELECT p.category_id, SUM(oi.quantity) AS delivered_quantity
FROM order_items AS oi
JOIN products AS p
ON oi.product_id = p.product_id
JOIN orders AS o
ON o.order_id = oi.order_id
WHERE o.order_status = "Delivered"
GROUP BY p.category_id
) SELECT c.category_name, cte1.ordered_quantity, cte2.delivered_quantity,
ROUND((cte2.delivered_quantity / cte1.ordered_quantity) * 100,2) AS fulfiillment_pct
FROM cte1 
JOIN cte2
ON cte1.category_id = cte2.category_id
JOIN categories AS c
ON c.category_id = cte1.category_id;

-- For each payment gateway calculate:Total payments,Successful payments,Failed payments,Success %
WITH cte1 AS(
SELECT payment_gateway,
COUNT(payment_id) AS total_payment,
COUNT(CASE WHEN payment_status = "Success" THEN payment_id END) AS success_payment,
COUNT(CASE WHEN payment_status = "Failed" THEN payment_id END) AS failed_payment
FROM payments
GROUP BY payment_gateway
) SELECT payment_gateway, total_payment, success_payment, failed_payment,
ROUND((success_payment / total_payment) * 100,2) AS success_pct
FROM cte1;

-- Calculate:High-value customers,Customers active in last 30 days,Active percentage
WITH cte1 AS (SELECT customer_id, SUM(net_amount) AS revenue
FROM orders
GROUP BY customer_id
HAVING SUM(net_amount) > 20000
), cte2 AS (
SELECT cte1.customer_id, cte1.revenue,
MAX(DATE(o.order_date)) AS last_order_date
FROM cte1 
JOIN orders AS o
ON cte1.customer_id = o.customer_id
GROUP BY cte1.customer_id
), cte3 AS(
SELECT customer_id, revenue, last_order_date,
DATEDIFF(CURDATE(),last_order_date) AS gap_in_days
FROM cte2
), cte4 AS (
SELECT COUNT(customer_id) AS hv_customers,
COUNT(CASE WHEN gap_in_days < 30 THEN customer_id END) AS active_hv_customers
FROM cte3
) SELECT hv_customers, active_hv_customers,
ROUND((active_hv_customers / hv_customers) * 100,2) AS active_pct
FROM cte4;

-- Create one dashboard query showing:Metrics-Total Customers,Session Customers,Ordering Customers,Successful Payment Customers,Delivered Customers
WITH cte1 AS(
SELECT (SELECT COUNT(customer_id) FROM customers) AS total_customers,
(SELECT COUNT(customer_id) FROM customer_sessions) AS session_customer,
(SELECT COUNT(customer_id) FROM orders) AS ordering_customer,
(SELECT COUNT(payment_id) FROM payments WHERE payment_status = "Success") AS success_payment_customer,
(SELECT COUNT(order_id) FROM orders WHERE order_status = "Delivered") AS delivered_customer
) SELECT *,
ROUND((ordering_customer / session_customer) *100,2) AS order_conversion_pct,
ROUND((success_payment_customer / ordering_customer) *100,2) AS payment_conversion_pct,
ROUND((delivered_customer / ordering_customer) *100,2) AS delivery_conversion_pct
FROM cte1;

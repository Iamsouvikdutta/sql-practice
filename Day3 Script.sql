-- QUESTION 1 — Delivered vs Cancelled Revenue Find city-wise:delivered revenue,cancelled order value,returned order value
SELECT c.city_name , 
ROUND(SUM(CASE WHEN o.order_status = "Delivered" THEN (o.net_amount) END),2) AS "Delivered_Revenue",
ROUND(SUM(CASE WHEN o.order_status = "Cancelled" THEN (o.net_amount) END),2) AS "Cancelled_Revenue",
ROUND(SUM(CASE WHEN o.order_status = "Returned" THEN (o.net_amount) END ),2)AS "Returned_Revenue"
FROM cities as c
LEFT JOIN orders as o
ON c.city_id = o.city_id
GROUP BY c.city_name;

-- QUESTION 2 — Customer Type Performance Find:total customers,average order value,total revenue for each type of customer
SELECT 
COUNT( DISTINCT CASE WHEN c.customer_type = "Regular" THEN c.customer_id END) AS "Regular_Customers",
COUNT( DISTINCT CASE WHEN c.customer_type = "Frequent" THEN c.customer_id END) AS "Frequent_Customers",
COUNT( DISTINCT CASE WHEN c.customer_type = "Inactive" THEN c.customer_id END) AS "Inactive_Customers",
COUNT( DISTINCT CASE WHEN c.customer_type = "High Value" THEN c.customer_id END) AS "Inactive_Customers",
AVG( CASE WHEN c.customer_type = "Regular" AND o.order_status = "Delivered" THEN o.net_amount END) AS "Regular_Customers_AOV",
AVG( CASE WHEN c.customer_type = "Frequent" AND o.order_status = "Delivered" THEN o.net_amount END) AS "Frequent_Customers_AOV",
AVG( CASE WHEN c.customer_type = "Inactive" AND o.order_status = "Delivered"THEN o.net_amount END) AS "Inactive_Customers_AOV",
AVG( CASE WHEN c.customer_type = "High Value" AND o.order_status = "Delivered" THEN o.net_amount END) AS "Inactive_Customers_AOV",
SUM( CASE WHEN c.customer_type = "Regular" AND o.order_status = "Delivered" THEN o.net_amount END) AS "Regular_Customers_Revenue",
SUM( CASE WHEN c.customer_type = "Frequent" AND o.order_status = "Delivered" THEN o.net_amount END) AS "Frequent_Customers_Revenue",
SUM( CASE WHEN c.customer_type = "Inactive" AND o.order_status = "Delivered" THEN o.net_amount END) AS "Inactive_Customers_Revenue",
SUM( CASE WHEN c.customer_type = "High Value" AND o.order_status = "Delivered" THEN o.net_amount END) AS "Inactive_Customers_Revenue"
FROM customers as c
LEFT JOIN orders as o
ON c.customer_id = o.customer_id;

-- QUESTION 3 — Active vs Inactive Products Find category-wise:active products, inactive products
SELECT c.category_name,
COUNT( CASE WHEN p.is_active = 0 THEN p.product_id END ) AS "Inactive Product",
COUNT( CASE WHEN p.is_active = 1 THEN p.product_id END ) AS "Active Product"
FROM categories as c
LEFT JOIN products as p
ON c.category_id = p.category_id
GROUP BY c.category_name;

-- QUESTION 4 — Payment Success Analysis Find payment gateway-wise:successful payments, failed payments, refunded payments, success percentage
WITH cte1 AS (
SELECT payment_gateway, Payment_status, 
COUNT(payment_id) AS Total_Payments
FROM payments 
GROUP BY payment_gateway, Payment_status 
)
SELECT payment_gateway, Payment_status, Total_Payments,
    SUM(Total_Payments) OVER(PARTITION BY payment_gateway) AS Gateway_Grand_Total,
    ROUND((Total_Payments / SUM(Total_Payments) OVER(PARTITION BY payment_gateway)) * 100, 2) AS Status_Payment_PCT
FROM cte1
ORDER BY payment_gateway ASC, Total_Payments DESC;

-- QUESTION 5 — Customer Order Segmentation
WITH cte1 AS (
SELECT customer_id, SUM(net_amount) AS Total_Revenue
FROM orders
WHERE order_status = "Delivered"
GROUP BY 1
)
SELECT customer_id, Total_Revenue,
CASE WHEN Total_Revenue > 20000 THEN "High Value"
WHEN Total_Revenue > 10000 AND Total_Revenue < 20000 THEN "Medium Value"
ELSE "Low Value" END AS "Customer_Segmentation"
FROM cte1;

-- QUESTION 6 — Campaign Efficiency Analysis
WITH CTE1 AS (
SELECT c.campaign_name, o.order_status, COUNT(o.order_id) AS Status_order_count
FROM campaigns as c
LEFT JOIN orders as o
ON c.campaign_id = o.campaign_id
GROUP BY 1,2
) ,cte2 AS (
SELECT campaign_name, order_status, Status_Order_Count,
SUM(Status_Order_Count) OVER (Partition BY campaign_name) AS Campaign_Total_Order,
(SUM(status_order_count) OVER (PARTITION BY campaign_name) / Status_order_count) AS Pct_rate
FROM cte1
GROUP BY 1,2
)
SELECT campaign_name, campaign_total_order AS Total_order,
CASE WHEN order_status = "Delivered" Then Status_Order_Count END AS Delivered_order,
CASE WHEN order_status = "cancelled" THEN Pct_rate END AS Cancellation_rate
FROM cte2
WHERE order_status <> "Returned";

-- QUESTION 7 — Product Revenue Contribution
WITH cte1 AS (
SELECT c.category_name, SUM(p.selling_price) AS Revenue
FROM categories AS c
LEFT JOIN products AS p ON c.category_id = p.category_id
WHERE p.is_active = 1
GROUP BY c.category_name
)
SELECT category_name, Revenue AS Category_Revenue,
SUM(Revenue) OVER() AS Total_Business_Revenue,
ROUND((Revenue / SUM(Revenue) OVER()) * 100, 2) AS Business_Contri_PCT
FROM cte1
ORDER BY Category_Revenue DESC;

-- QUESTION 8 — Monthly Delivered vs Cancelled Orders
SELECT DATE_FORMAT(order_date, "%Y-%m") AS "Year_Month",
order_status, COUNT(order_id) AS Total_orders
FROM orders
WHERE order_status <> "Returned"
GROUP BY DATE_FORMAT(order_date, "%Y-%m"), order_status
ORDER BY DATE_FORMAT(order_date, "%Y-%m") ASC;

-- QUESTION 9 — Fast vs Slow Delivery Cities
WITH cte1 AS (
SELECT city_id, ROUND(AVG(delivery_time_mins),0) AS avg_delivery_time
FROM orders
GROUP BY city_id
)
SELECT c.city_name, cte1.avg_delivery_time,
CASE WHEN avg_delivery_time <= 20 THEN "Fast"
WHEN avg_delivery_time >= 20 AND avg_delivery_time <= 35 THEN "Modarate"
ELSE "Slow" END AS Delivery_Category
FROM cities as c 
JOIN cte1 AS cte1
ON c.city_id = cte1.city_id;

-- QUESTION 10 — Customer Retention Indicator
WITH cte1 AS (
SELECT customer_id, COUNT(order_id) AS No_of_orders,
SUM(net_amount) AS Revenue
FROM orders
WHERE order_status = "Delivered"
GROUP BY customer_id
) 
SELECT customer_id, Revenue, 
CASE WHEN No_of_orders > 5 THEN "Loyal"
WHEN No_of_orders >=3 AND No_of_orders <= 5 THEN "Regular"
ELSE "Risk" END AS "Retention_Flag"
FROM cte1
WHERE No_of_orders > 5;


-- Find the top 3 highest revenue-generating products inside each category.
WITH CTE1 AS (
SELECT c.category_name , p.product_name, SUM(oi.quantity * oi.item_price) AS Product_Revenue
FROM categories AS c
JOIN products AS p
On c.category_id = p.category_id
JOIN order_items as oi
ON oi.product_id = p.product_id
JOIN orders as o
ON oi.order_id = o.order_id
WHERE o.order_status = "Delivered"
GROUP BY 1,2
ORDER BY category_name
),cte2 AS(
SELECT category_name, product_name, product_revenue,
DENSE_RANK() OVER( PARTITION BY category_name ORDER BY product_Revenue DESC) AS Product_rank
FROM cte1
)
SELECT category_name, product_name, product_revenue, product_rank
FROM cte2
WHERE product_rank <=3;
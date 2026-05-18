-- Find the top 10 highest net amount orders.

SELECT order_id, customer_id, net_amount
FROM orders
ORDER BY net_amount DESC
LIMIT 10;

-- Find all cancelled orders placed in the last 90 days.
SELECT order_id, customer_id, order_date, city_id, order_status
FROM orders
WHERE order_date < CURDATE() - INTERVAL 90 DAY
AND order_status = "cancelled";

-- Show distinct cities where at least one delivered order exists.
SELECT DISTINCT city_id
FROM orders
WHERE order_status = "delivered";

-- Find products with rating above 4.0,stock quantity greater than 100

SELECT product_id, product_name, rating, Stock_quantity
FROM products
WHERE rating > 4.0 AND stock_quantity >100;

-- Find orders delivered in under 15 minutes.

SELECT order_id, delivery_time_mins, city_id
FROM orders
WHERE delivery_time_mins <= 15;

-- Find all orders paid using:Wallet,UPI
SELECT order_id, payment_method, net_amount
FROM orders 
WHERE payment_method IN ( "wallet", "UPI")
ORDER BY net_amount DESC;

-- Find the 15 most expensive active products.
SELECT product_id, product_name, selling_price
FROM products
WHERE is_active = 1
ORDER BY selling_price DESC
LIMIT 15;

-- Find customers:age between 18 and 25,customer_type = 'Frequent'
SELECT customer_id, customer_name, age, customer_type
FROM customers
WHERE (age BETWEEN 18 AND 25)
AND customer_type = "Frequent";

-- customers from Kolkata with orders > ₹500
SELECT cu.customer_id, ci.city_name, SUM(o.net_amount) AS Net_Amount
FROM customers AS cu
JOIN cities AS ci
ON cu.city_id = ci.city_id
JOIN orders AS o
ON cu.customer_id = o.customer_id
WHERE o.net_amount > 500
AND o.order_status = "Delivered"
AND ci.city_name = "Kolkata"
GROUP BY 1,2
ORDER BY SUM(Net_AMOUNT) DESC;

-- orders placed in last 30 days
SELECT order_id
FROM orders
WHERE order_date > CURDATE() - INTERVAL 30 Day;

-- customers NOT using UPI
SELECT customer_id 
FROM orders
WHERE payment_method <> "UPI";


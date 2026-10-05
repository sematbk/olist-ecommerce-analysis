-- ============================================
-- OLIST E-COMMERCE DATA ANALYSIS
-- Part 1: Data validation
-- ============================================

-- 1.1 Row counts per table (sanity check after import)
SELECT 'orders' AS table_name, COUNT(*) AS rows FROM olist_orders_dataset
UNION ALL SELECT 'order_items', COUNT(*) FROM olist_order_items_dataset
UNION ALL SELECT 'payments', COUNT(*) FROM olist_order_payments_dataset
UNION ALL SELECT 'reviews', COUNT(*) FROM olist_order_reviews_dataset
UNION ALL SELECT 'products', COUNT(*) FROM olist_products_dataset
UNION ALL SELECT 'sellers', COUNT(*) FROM olist_sellers_dataset
UNION ALL SELECT 'category_translation', COUNT(*) FROM product_category_name_translation;

-- 1.2 Date range covered by the data
SELECT MIN(order_purchase_timestamp) AS first_order,
       MAX(order_purchase_timestamp) AS last_order
FROM olist_orders_dataset;

-- 1.3 Order status distribution
SELECT order_status, COUNT(*) AS count
FROM olist_orders_dataset
GROUP BY order_status
ORDER BY count DESC;

-- 1.4 Monthly order volume (2016 and late 2018 are known to be incomplete)
SELECT strftime('%Y-%m', order_purchase_timestamp) AS month,
       COUNT(*) AS order_count
FROM olist_orders_dataset
GROUP BY month
ORDER BY month;

-- ============================================
-- Part 2: Revenue analysis
-- Scope: delivered orders only, Jan 2017 - Aug 2018 (20 full months)
-- ============================================

-- 2.1 Monthly revenue and order count
SELECT strftime('%Y-%m', o.order_purchase_timestamp) AS month,
       COUNT(DISTINCT o.order_id) AS order_count,
       ROUND(SUM(i.price), 2) AS revenue
FROM olist_orders_dataset o
JOIN olist_order_items_dataset i ON o.order_id = i.order_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01'
GROUP BY month
ORDER BY month;

-- 2.2 Top 3 months by revenue
SELECT strftime('%Y-%m', o.order_purchase_timestamp) AS month,
       COUNT(DISTINCT o.order_id) AS order_count,
       ROUND(SUM(i.price), 2) AS revenue
FROM olist_orders_dataset o
JOIN olist_order_items_dataset i ON o.order_id = i.order_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01'
GROUP BY month
ORDER BY revenue DESC
LIMIT 3;

-- 2.3 Daily order volume in November 2017 (Black Friday check)
SELECT DATE(order_purchase_timestamp) AS day,
       COUNT(*) AS order_count
FROM olist_orders_dataset
WHERE order_purchase_timestamp >= '2017-11-01'
  AND order_purchase_timestamp <  '2017-12-01'
GROUP BY day
ORDER BY order_count DESC
LIMIT 5;

-- 2.4 Revenue by category and share of total (top 10)
SELECT COALESCE(t.product_category_name_english,
                p.product_category_name,
                'unknown') AS category,
       COUNT(DISTINCT o.order_id) AS order_count,
       ROUND(SUM(i.price), 2) AS revenue,
       ROUND(100.0 * SUM(i.price) / SUM(SUM(i.price)) OVER (), 2) AS pct_of_total
FROM olist_orders_dataset o
JOIN olist_order_items_dataset i ON o.order_id = i.order_id
JOIN olist_products_dataset p ON i.product_id = p.product_id
LEFT JOIN product_category_name_translation t
       ON p.product_category_name = t.product_category_name
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01'
GROUP BY category
ORDER BY revenue DESC
LIMIT 10;

-- 2.5 Category revenue concentration (Pareto / 80-20 analysis)
WITH category_revenue AS (
    SELECT COALESCE(t.product_category_name_english,
                    p.product_category_name,
                    'unknown') AS category,
           SUM(i.price) AS revenue
    FROM olist_orders_dataset o
    JOIN olist_order_items_dataset i ON o.order_id = i.order_id
    JOIN olist_products_dataset p ON i.product_id = p.product_id
    LEFT JOIN product_category_name_translation t
           ON p.product_category_name = t.product_category_name
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY category
)
SELECT ROW_NUMBER() OVER (ORDER BY revenue DESC) AS rank,
       category,
       ROUND(revenue, 2) AS revenue,
       ROUND(100.0 * revenue / SUM(revenue) OVER (), 2) AS pct_of_total,
       ROUND(100.0 * SUM(revenue) OVER (ORDER BY revenue DESC)
             / SUM(revenue) OVER (), 2) AS cumulative_pct
FROM category_revenue
ORDER BY revenue DESC;

-- ============================================
-- Part 3: Customer analysis (RFM)
-- Customer identifier: customer_unique_id (NOT customer_id,
-- which is generated per order)
-- Reference date: 2018-09-01 (end of analysis window)
-- ============================================

-- 3.1 Distribution of orders per customer
SELECT frequency, COUNT(*) AS customer_count
FROM (
    SELECT c.customer_unique_id,
           COUNT(DISTINCT o.order_id) AS frequency
    FROM olist_orders_dataset o
    JOIN olist_customers_dataset c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY c.customer_unique_id
)
GROUP BY frequency
ORDER BY frequency;

-- 3.2 Top 10 customers by total spend (raw RFM values)
SELECT c.customer_unique_id,
       CAST(julianday('2018-09-01') - julianday(MAX(o.order_purchase_timestamp)) AS INTEGER) AS recency_days,
       COUNT(DISTINCT o.order_id) AS frequency,
       ROUND(SUM(i.price), 2) AS monetary
FROM olist_orders_dataset o
JOIN olist_customers_dataset c ON o.customer_id = c.customer_id
JOIN olist_order_items_dataset i ON o.order_id = i.order_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01'
GROUP BY c.customer_unique_id
ORDER BY monetary DESC
LIMIT 10;

-- 3.3 Repeat-purchase rate by first-order cohort (checks whether the
-- low overall repeat rate is just a short-window effect)
WITH customer AS (
    SELECT c.customer_unique_id,
           MIN(o.order_purchase_timestamp) AS first_order,
           COUNT(DISTINCT o.order_id) AS order_count
    FROM olist_orders_dataset o
    JOIN olist_customers_dataset c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY c.customer_unique_id
)
SELECT strftime('%Y-%m', first_order) AS first_order_month,
       COUNT(*) AS customer_count,
       SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) AS repeat_customers,
       ROUND(100.0 * SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END)
             / COUNT(*), 2) AS repeat_pct
FROM customer
GROUP BY first_order_month
ORDER BY first_order_month;

-- 3.4 RFM scoring and segmentation
-- R: 5 = most recent purchase, M: 5 = highest spend
-- F: 1 = single order, 2 = two orders, 3 = three or more (frequency is
-- heavily skewed toward 1, so a plain NTILE(5) on F would not be meaningful)
WITH customer AS (
    SELECT c.customer_unique_id,
           CAST(julianday('2018-09-01') - julianday(MAX(o.order_purchase_timestamp)) AS INTEGER) AS recency_days,
           COUNT(DISTINCT o.order_id) AS frequency,
           SUM(i.price) AS monetary
    FROM olist_orders_dataset o
    JOIN olist_customers_dataset c ON o.customer_id = c.customer_id
    JOIN olist_order_items_dataset i ON o.order_id = i.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY c.customer_unique_id
),
scored AS (
    SELECT *,
           6 - NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score,
           CASE WHEN frequency = 1 THEN 1
                WHEN frequency = 2 THEN 2
                ELSE 3 END AS f_score,
           NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
    FROM customer
),
segmented AS (
    SELECT *,
           CASE
               WHEN f_score >= 2 AND r_score >= 4 THEN '1 Active loyal'
               WHEN f_score >= 2 THEN '2 Dormant loyal'
               WHEN r_score >= 4 AND m_score >= 4 THEN '3 New high spender'
               WHEN r_score >= 4 THEN '4 New low/mid spender'
               WHEN m_score >= 4 THEN '5 Lost high spender'
               ELSE '6 Lost low/mid spender'
           END AS segment
    FROM scored
)
SELECT segment,
       COUNT(*) AS customer_count,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS customer_pct,
       ROUND(SUM(monetary), 2) AS revenue,
       ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 2) AS revenue_pct
FROM segmented
GROUP BY segment
ORDER BY segment;

-- ============================================
-- Part 4: Delivery performance and customer satisfaction
-- Delay = actual delivery date - estimated delivery date (days)
-- ============================================

-- 4.1 Average review score by delay bucket
WITH order_delay AS (
    SELECT o.order_id,
           julianday(o.order_delivered_customer_date)
             - julianday(o.order_estimated_delivery_date) AS delay_days,
           AVG(r.review_score) AS score
    FROM olist_orders_dataset o
    JOIN olist_order_reviews_dataset r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_delivered_customer_date <> ''
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY o.order_id
)
SELECT CASE
           WHEN delay_days <= 0 THEN '1 On time or early'
           WHEN delay_days <= 3 THEN '2 Slightly late (up to 3 days)'
           WHEN delay_days <= 7 THEN '3 Moderately late (3-7 days)'
           ELSE '4 Very late (more than 7 days)'
       END AS delay_bucket,
       COUNT(*) AS order_count,
       ROUND(AVG(score), 2) AS avg_review_score
FROM order_delay
GROUP BY delay_bucket
ORDER BY delay_bucket;

-- 4.2 Delivery time and late-delivery rate by state
SELECT c.customer_state AS state,
       COUNT(*) AS order_count,
       ROUND(AVG(julianday(o.order_delivered_customer_date)
                 - julianday(o.order_purchase_timestamp)), 1) AS avg_delivery_days,
       ROUND(100.0 * SUM(CASE WHEN julianday(o.order_delivered_customer_date)
                                  > julianday(o.order_estimated_delivery_date)
                              THEN 1 ELSE 0 END) / COUNT(*), 2) AS late_pct
FROM olist_orders_dataset o
JOIN olist_customers_dataset c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_delivered_customer_date <> ''
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01'
GROUP BY state
HAVING COUNT(*) >= 100
ORDER BY late_pct DESC;

-- 4.3 Estimated vs. actual delivery time by state
-- (checks whether late-delivery states simply get overly optimistic
-- estimates, or whether delivery times are just highly variable)
SELECT c.customer_state AS state,
       COUNT(*) AS order_count,
       ROUND(AVG(julianday(o.order_estimated_delivery_date)
                 - julianday(o.order_purchase_timestamp)), 1) AS estimated_days,
       ROUND(AVG(julianday(o.order_delivered_customer_date)
                 - julianday(o.order_purchase_timestamp)), 1) AS actual_days,
       ROUND(AVG(julianday(o.order_delivered_customer_date)
                 - julianday(o.order_estimated_delivery_date)), 1) AS avg_diff_days
FROM olist_orders_dataset o
JOIN olist_customers_dataset c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_delivered_customer_date <> ''
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01'
GROUP BY state
HAVING COUNT(*) >= 100
ORDER BY avg_diff_days DESC;
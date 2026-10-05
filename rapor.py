import sqlite3
import pandas as pd
import matplotlib.pyplot as plt

# 1. Connect to the database
conn = sqlite3.connect("olist.db")

# 2. Queries (same as 2.1, 2.4 and 4.1 in analiz.sql)
query_monthly_revenue = """
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
"""

query_category = """
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
"""

query_delivery = """
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
"""

# 3. Run the queries and load results into DataFrames
monthly_revenue = pd.read_sql_query(query_monthly_revenue, conn)
category = pd.read_sql_query(query_category, conn)
delivery = pd.read_sql_query(query_delivery, conn)

# 4. Write all three tables into one Excel file, each on its own sheet
with pd.ExcelWriter("olist_report.xlsx") as writer:
    monthly_revenue.to_excel(writer, sheet_name="Monthly revenue", index=False)
    category.to_excel(writer, sheet_name="Top 10 categories", index=False)
    delivery.to_excel(writer, sheet_name="Delivery vs rating", index=False)

conn.close()
print("Report created: olist_report.xlsx")

# 5. Save the monthly revenue trend as a chart
plt.figure(figsize=(10, 5))
plt.plot(monthly_revenue["month"], monthly_revenue["revenue"], marker="o")
plt.title("Monthly Revenue (Jan 2017 - Aug 2018)")
plt.xlabel("Month")
plt.ylabel("Revenue (BRL)")
plt.xticks(rotation=45)
plt.grid(True)
plt.tight_layout()
plt.savefig("monthly_revenue_chart.png")
print("Chart created: monthly_revenue_chart.png")

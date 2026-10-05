# Olist E-Commerce Data Analysis

An end-to-end SQL and Python analysis of the [Olist Brazilian E-Commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (~100k orders, 2016–2018), covering revenue trends, category performance, customer segmentation (RFM), and delivery performance.

This project was built as a self-directed portfolio project to demonstrate practical SQL and Python skills for a data/business analyst role, since I'm a recent graduate without prior internship experience.

## Tools used

- **SQLite** (via DB Browser for SQLite) for data modeling and analysis
- **Python** (pandas, matplotlib) for reporting automation and a trend chart
- **Excel** as the output format for the automated report

## Project structure

```
├── olist.db                     # SQLite database (9 CSV tables imported)
├── analysis.sql                   # All SQL queries, organized in 4 parts
├── rapor.py                     # Python script: re-runs 3 key queries and
│                                 # builds an Excel report + a trend chart
├── olist_report.xlsx            # Output: 3-sheet Excel report
├── monthly_revenue_chart.png    # Output: monthly revenue trend chart
└── README.md
```

## Scope and assumptions

- **Analysis window:** January 2017 – August 2018 (20 full months). The raw data starts on 2016-09-04 and ends on 2018-10-17, but both edges contain very few orders and would distort any trend analysis, so they were excluded.
- **Revenue** is calculated only from orders with status `delivered`, and does not include freight cost — only the `price` column from `order_items`. Currency is Brazilian Real (BRL).
- **Customer identity:** the dataset's `customer_id` is generated per order, not per person. All customer-level analysis (repeat-purchase rate, RFM) uses `customer_unique_id` instead.
- Segment boundaries in the RFM analysis are approximate, since `NTILE` splits ties in the recency column somewhat arbitrarily.

## Key findings

### 1. Revenue trend
- Revenue peaked in **November 2017** (987,765 BRL), driven by Black Friday: November 24, 2017 alone had 1,176 orders, more than double the second-busiest day.
- Through 2018, revenue stayed close to that peak (Figure: April and May 2018 were within ~1% of the November 2017 level) rather than continuing to grow or declining, suggesting the business plateaued at a higher base level rather than losing momentum.

### 2. Category concentration
- The top 3 categories by revenue are **health & beauty** (9.3%), **watches & gifts** (8.8%), and **bed, bath & table** (7.8%) — no single category dominates.
- However, 18 of the 74 categories (24%) account for 81% of total revenue, a Pareto-like concentration. This analysis only covers revenue, not margin, so a recommendation to deprioritize low-revenue categories would need profitability data to be justified.

### 3. Customer retention is weak
- About 97% of customers placed only a single order during the analysis window.
- This is partly a measurement-window effect: customers who first ordered in Jan–Mar 2017 had a 4–7% repeat rate, vs. 0.5–1.5% for those who first ordered in Jul–Aug 2018 (less time to return). But even the most mature cohorts show a repeat rate well under 10%, so the underlying loyalty problem is real, not just a short observation window.
- RFM segmentation shows that customers who haven't ordered recently but previously spent a lot ("lost high spenders") are 22% of customers but 42% of revenue — a natural target for win-back campaigns. "New high spenders" (15% of customers, 29% of revenue) are a second high-value segment, better suited to second-purchase campaigns since they ordered more recently.

### 4. Delivery delays strongly correlate with low review scores
- Orders delivered more than 7 days after the estimated date average a 1.73 review score, vs. 4.30 for on-time/early orders.
- The drop is not linear: delays of up to 3 days barely affect the score (3.77); the sharp decline starts past the 3-day mark.
- Northeastern states (Alagoas, Maranhão, Piauí) have the highest late-delivery rates, while Amazonas has the longest average delivery time. Interestingly, estimated delivery windows are on average generous in all states (deliveries arrive before the estimate on average), which suggests the issue in the Northeast is delivery-time **variability**, not a biased estimate.

## How to reproduce

1. Download the dataset from Kaggle and import the CSVs into a SQLite database named `olist.db` (table names should match the original CSV file names).
2. Run the queries in `analysis.sql` directly in a SQL client (e.g., DB Browser for SQLite), or
3. Run `python rapor.py` from the project folder to regenerate `olist_report.xlsx` and `monthly_revenue_chart.png` automatically.

## Possible next steps

- Join seller-level data to analyze seller concentration and performance.
- Add order profitability (would require cost data not present in this dataset) to validate the category-concentration recommendation.
- Rebuild the dashboard in Power BI or Tableau for an interactive version of these findings.

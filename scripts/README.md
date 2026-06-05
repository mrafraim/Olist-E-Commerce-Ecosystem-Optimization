# Data Cleaning & Exploratory Data Analysis (EDA)

Raw data is never perfectly clean. Before creating high-level KPIs, business dashboards, or reporting metrics, we must uncover and fix data anomalies.

We have created a brand new script for this entire phase:

`📁 03_data_cleaning_eda.sql`

## Data Quality Assessment: Fulfillment Timelines

```sql
-- =============================================================================
-- STEP 1: ANALYZING MISSING DELIVERY DATES BY ORDER STATUS
-- Goal: Understand if missing delivery dates represent system errors (dirty data)
--       or logical business states (e.g., a canceled order shouldn't have a delivery date).
-- =============================================================================

SELECT 
    order_status,
    COUNT(*) AS total_orders,
    
    -- COUNT(column) only counts non-null records; helps track actual completions
    COUNT(order_delivered_customer_date) AS non_null_deliveries,
    
    -- Subtracting non-null entries from total rows isolates the volume of missing data
    COUNT(*) - COUNT(order_delivered_customer_date) AS missing_delivery_dates

FROM olist_orders
GROUP BY order_status
ORDER BY missing_delivery_dates DESC;
```
Output:

![ANALYZING MISSING DELIVERY DATES BY ORDER STATUS](outputs/2.1.jpg)

We found 8 orders marked "delivered" that are missing a delivery date. To keep our shipping stats accurate, we are leaving these 8 orders out of our calculations.

## Structural Root-Cause Analysis of Delivery Anomalies

```sql
-- =============================================================================
-- STEP 2: ISOLATING THE 8 DATA ANOMALIES
-- Goal: Extract the exact 'delivered' rows missing a customer timestamp.
--       We need to see if there is a pattern (e.g., did they all happen on the 
--       same day or during a specific system outage window?).
-- =============================================================================

SELECT 
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_estimated_delivery_date
FROM olist_orders
WHERE order_status = 'delivered' 
  AND order_delivered_customer_date IS NULL;
```
Output:

![ISOLATING THE 8 DATA ANOMALIES](outputs/2.2.jpg)

During our data health check, we discovered a tiny bug in how our delivery dates were recorded. Out of nearly 100,000 completed orders, **exactly 8 orders** are marked as "Delivered" but are missing their actual delivery date stamps.

When we isolated those 8 broken orders, we found a clear pattern:

* **75% of these errors happened in June and July 2018.**
* **3 of the errors happened on the exact same day** (July 1, 2018).

Because these errors happened at almost the same time, this wasn't a human typing mistake. It points heavily to a temporary **software glitch or a system connection failure** with our delivery partners during that specific summer window.

#### Our Business Action Plan

> **Decision:** Exclude these 8 orders from shipping speed reports.
> Since we can't guess the exact days these packages arrived, we will programmatically skip these 8 specific orders when calculating our "Average Shipping Times." Leaving them in would break our formulas, but removing them ensures our business dashboards remain **100% accurate.**

/*******************************************************************************
Script Name:  03_business_kpis.sql
Description:  Business Intelligence KPIs. Establishing 
              financial baselines and category performance metrics.
Author:       Mostafizur Rahman
*******************************************************************************/

-- =============================================================================
-- STEP 1: GLOBAL FINANCIAL BASELINE
-- Goal: Calculate undisputed totals for Revenue, Volume, and AOV.
-- Filter: Exclude non-transactional states (canceled/unavailable).
-- =============================================================================

SELECT 
    ROUND(SUM(price)::NUMERIC, 2) AS total_revenue,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND((SUM(price) / COUNT(DISTINCT order_id))::NUMERIC, 2) AS average_order_value
FROM olist_order_items
WHERE order_id IN (
    SELECT order_id 
    FROM olist_orders 
    WHERE order_status NOT IN ('canceled', 'unavailable')
);				


-- =============================================================================
-- STEP 2: REVENUE DISTRIBUTION BY CATEGORY
-- Goal: Break down total revenue and order volume by product category.
-- =============================================================================

SELECT 
    COALESCE(p.product_category_name, 'unassigned') AS category_name,
    ROUND(SUM(oi.price)::NUMERIC, 2) AS category_revenue,
    COUNT(DISTINCT oi.order_id) AS category_orders
FROM olist_order_items oi
JOIN olist_products p ON oi.product_id = p.product_id
WHERE oi.order_id IN (
    SELECT order_id 
    FROM olist_orders 
    WHERE order_status NOT IN ('canceled', 'unavailable')
)
GROUP BY p.product_category_name
ORDER BY category_revenue DESC;

-- =============================================================================
-- STEP 3: PARETO ANALYSIS (80/20 RULE) ON PRODUCT CATEGORIES
-- Goal: Calculate running revenues and cumulative percentages to isolate the 
--       exact product categories driving 80% of platform turnover.
-- =============================================================================

WITH CategoryRevenue AS (
    -- Subquery 1: Extract baseline revenue per category (excluding canceled/unavailable)
    SELECT 
        COALESCE(p.product_category_name, 'unassigned') AS category_name,
        SUM(oi.price) AS category_revenue
    FROM olist_order_items oi
    JOIN olist_products p ON oi.product_id = p.product_id
    WHERE oi.order_id IN (
        SELECT order_id 
        FROM olist_orders 
        WHERE order_status NOT IN ('canceled', 'unavailable')
    )
    GROUP BY p.product_category_name
),
RunningCalculations AS (
    -- Subquery 2: Compute running total revenue and get the absolute grand total
    SELECT 
        category_name,
        category_revenue,
        -- Running total orders from highest revenue to lowest
        SUM(category_revenue) OVER (ORDER BY category_revenue DESC) AS running_revenue,
        -- Total revenue across the entire platform for percentage math
        SUM(category_revenue) OVER () AS total_platform_revenue
    FROM CategoryRevenue
)
-- Step 3: Output categories alongside their cumulative financial share
SELECT 
    category_name,
    ROUND(category_revenue::NUMERIC, 2) AS category_revenue,
    ROUND(((running_revenue / total_platform_revenue) * 100)::NUMERIC, 2) AS cumulative_percentage
FROM RunningCalculations
ORDER BY category_revenue DESC;

-- =============================================================================
-- STEP 4: OPERATIONAL SHIPPING LATENCY & PREDICTION ACCURACY
-- Goal: Calculate average fulfillment times and determine how many days 
--       ahead or behind schedule packages are arriving.
-- Filter: Focus exclusively on completed 'delivered' orders and exclude the 
--         8 anomalous rows we found during data cleaning.
-- =============================================================================

SELECT 
    -- 1. Average actual days from purchase to customer delivery
    ROUND(AVG(EXTRACT(EPOCH FROM (order_delivered_customer_date - order_purchase_timestamp)) / 86400)::NUMERIC, 1) AS avg_actual_delivery_days,
    
    -- 2. Average days promised to the customer at checkout
    ROUND(AVG(EXTRACT(EPOCH FROM (order_estimated_delivery_date - order_purchase_timestamp)) / 86400)::NUMERIC, 1) AS avg_estimated_delivery_days,
    
    -- 3. Variance: positive number = arrived early, negative number = arrived late
    ROUND(AVG(EXTRACT(EPOCH FROM (order_estimated_delivery_date - order_delivered_customer_date)) / 86400)::NUMERIC, 1) AS avg_days_ahead_of_schedule
FROM olist_orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;

-- =============================================================================
-- STEP 5: SHIPPING VELOCITY VS. CUSTOMER SATISFACTION (REVIEW SCORES)
-- Goal: Analyze if delivery speed and estimation accuracy directly impact 
--       customer review scores.
-- =============================================================================

SELECT 
    r.review_score,
    COUNT(DISTINCT o.order_id) AS total_orders,
    -- Average actual days to deliver
    ROUND(AVG(EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)) / 86400)::NUMERIC, 1) AS avg_actual_delivery_days,
    -- Average days ahead of schedule (negative numbers would mean late)
    ROUND(AVG(EXTRACT(EPOCH FROM (o.order_estimated_delivery_date - o.order_delivered_customer_date)) / 86400)::NUMERIC, 1) AS avg_days_ahead_of_schedule
FROM olist_orders o
JOIN olist_order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY r.review_score
ORDER BY r.review_score DESC;
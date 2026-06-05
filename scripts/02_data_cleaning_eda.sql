/*******************************************************************************
Script Name:  03_data_cleaning_eda.sql
Description:  Investigating data quality, missing metrics, and operational 
              timelines across the core e-commerce tables.
Author:       Mostafizur Rahman
*******************************************************************************/

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
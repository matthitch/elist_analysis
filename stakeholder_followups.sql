-- 1) What were the order counts, sales, and AOV for Macbooks sold in North America for each quarter across all years?
SELECT
  DATE_TRUNC(ord.purchase_ts, QUARTER) AS purchase_quarter,
  COUNT(DISTINCT ord.id) AS order_count,
  ROUND(SUM(ord.usd_price), 2) AS total_sales,
  ROUND(AVG(ord.usd_price), 2) AS aov
FROM core.orders AS ord
LEFT JOIN core.customers AS cust
  ON ord.customer_id = cust.id
LEFT JOIN core.geo_lookup AS geo
  ON cust.country_code = geo.country_code
WHERE LOWER(ord.product_name) LIKE '%macbook%'
  AND geo.region = 'NA'
GROUP BY purchase_quarter
ORDER BY purchase_quarter DESC;


-- 2) For products purchased in 2022 on the website or products purchased on mobile in any year, which region has the average highest time to deliver?
SELECT
  geo.region,
  ROUND(AVG(DATE_DIFF(os.delivery_ts, os.purchase_ts, DAY)), 3) AS avg_days_to_deliver
FROM core.order_status AS os
LEFT JOIN core.orders AS ord
  ON os.order_id = ord.id
LEFT JOIN core.customers AS cust
  ON ord.customer_id = cust.id
LEFT JOIN core.geo_lookup AS geo
  ON cust.country_code = geo.country_code
WHERE (EXTRACT(YEAR FROM ord.purchase_ts) = 2022 AND ord.purchase_platform = 'website')
  OR ord.purchase_platform = 'mobile app'
GROUP BY geo.region
ORDER BY avg_days_to_deliver DESC;


-- 3) What was the refund rate and refund count for each product overall?
SELECT
  CASE WHEN ord.product_name = '27in"" 4k gaming monitor' THEN '27in 4K gaming monitor'
    ELSE ord.product_name
  END AS product_clean,
  SUM(CASE WHEN os.refund_ts IS NOT NULL THEN 1 ELSE 0 END) AS refunds,
  ROUND(AVG(CASE WHEN os.refund_ts IS NOT NULL THEN 1 ELSE 0 END), 3) AS refund_rate
FROM core.orders AS ord
LEFT JOIN core.order_status AS os
  ON ord.id = os.order_id
GROUP BY product_clean
ORDER BY refund_rate DESC;


-- 4) Within each region, what is the most popular product?
WITH sales_by_product AS (
  SELECT
    geo.region,
    CASE WHEN ord.product_name = '27in"" 4k gaming monitor' THEN '27in 4K gaming monitor'
      ELSE ord.product_name
    END AS product_clean,
    COUNT(DISTINCT ord.id) AS total_orders
  FROM core.orders AS ord
  LEFT JOIN core.customers AS cust
    ON ord.customer_id = cust.id
  LEFT JOIN core.geo_lookup AS geo
    ON cust.country_code = geo.country_code
  GROUP BY geo.region, product_clean
),
ranked_products AS (
  SELECT
    region,
    product_clean,
    total_orders,
    ROW_NUMBER() OVER (PARTITION BY region ORDER BY total_orders DESC) AS product_rank
  FROM sales_by_product
)
SELECT
  region,
  product_clean,
  total_orders
FROM ranked_products
WHERE product_rank = 1
ORDER BY region;


-- 5) How does the time to make a purchase differ between loyalty customers vs. non-loyalty customers?
SELECT
  cust.loyalty_program,
  ROUND(AVG(DATE_DIFF(ord.purchase_ts, cust.created_on, DAY)), 1) AS days_to_purchase,
  ROUND(AVG(DATE_DIFF(ord.purchase_ts, cust.created_on, MONTH)), 1) AS months_to_purchase
FROM core.customers AS cust
LEFT JOIN core.orders AS ord
  ON cust.id = ord.customer_id
WHERE cust.loyalty_program IS NOT NULL
  AND cust.created_on IS NOT NULL
GROUP BY cust.loyalty_program;

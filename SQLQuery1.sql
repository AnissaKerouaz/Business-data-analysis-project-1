--analysing sales performance over time.
--
SELECT 
YEAR(order_date) as order_year,
MONTH(order_date) as order_month,
SUM(sales_amount) as total_sales,
COUNT (DISTINCT customer_key) as total_customers,
SUM (quantity) as total_quantity
FROM [gold].[fact_sales]
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY YEAR(order_date), MONTH(order_date)

-- OR 

SELECT 
FORMAT(order_date, 'yyyy-MMM') as order_date,
SUM(sales_amount) as total_sales,
COUNT (DISTINCT customer_key) as total_customers,
SUM (quantity) as total_quantity
FROM [gold].[fact_sales]
WHERE order_date IS NOT NULL
GROUP BY FORMAT(order_date, 'yyyy-MMM')-- Groups results by year and month
ORDER BY FORMAT(order_date, 'yyyy-MMM')-- Sorts the results chronologically

--calculate the total sales per month
--calculate the running total of sales over time
SELECT 
order_date,
total_sales,
SUM (total_sales) OVER (PARTITION BY order_date ORDER BY order_date) AS running_total_sales--OVER tells SQL:“Apply this function across a set of rows, not just one row — and do it in a specific order or partition.”
--For each row, calculate the sum of total_sales **from the beginning
FROM 
(
SELECT 
CAST(DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1) AS DATE) AS order_date,
SUM(sales_amount) as total_sales
FROM [gold].[fact_sales]
where order_date IS NOT NULL
GROUP BY YEAR(order_date), MONTH(order_date)
) AS tableu --Run this subquery first, and call its result t so I can use it like a table.
--by the year
SELECT 
order_date,
total_sales,
SUM (total_sales) OVER ( ORDER BY order_date) AS running_total_sales--OVER tells SQL:“Apply this function across a set of rows, not just one row — and do it in a specific order or partition.”
--For each row, calculate the sum of total_sales **from the beginning
FROM 
(
SELECT 
CAST(DATEFROMPARTS(YEAR(order_date), 1, 1) AS DATE) AS order_date,
SUM(sales_amount) as total_sales
FROM [gold].[fact_sales]
where order_date IS NOT NULL
GROUP BY YEAR(order_date) -- ,MONTH(order_date)
) AS tableu

--analyse the yearly performance of products by comparing each product's sales to both 
--its average sales performance and the previous year's performance
WITH yearly_product_sales AS (
SELECT 
YEAR(f.order_date) AS order_year,
d.product_name,
SUM(f.sales_amount) AS current_sales
FROM [gold].[fact_sales] f
LEFT JOIN [gold].[dim_products] d
ON f.product_key = d.product_key
GROUP BY YEAR(f.order_date), d.product_name)
SELECT 
order_year,
product_name,
current_sales,
AVG(current_sales) OVER (PARTITION BY product_name) AS avg_sales,
current_sales - AVG(current_sales) OVER (PARTITION BY product_name) AS diff_avg,
CASE WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) > 0 THEN 'above avg'
     WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) < 0 THEN 'below avg'
	 ELSE 'avg'
END avg_change,
LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS porductyear_sales,
current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS diff_productyear,
CASE WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) > 0 THEN 'inc'
     WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) < 0 THEN 'dec'
	 ELSE 'no change'
END productyear_change
FROM yearly_product_sales
ORDER BY product_name, order_year

--propotional analysis/ part to whole
--which categories contribute the most to the overall sales.
WITH category_sales AS(
SELECT 
category, 
SUM(sales_amount) AS total_sales
FROM [gold].[fact_sales] f
LEFT JOIN [gold].[dim_products] p
ON p.product_key = f.product_key
GROUP BY category )
SELECT 
category,
total_sales,
SUM(total_sales) OVER () AS overall_sales,
CONCAT(ROUND ((CAST (total_sales AS FLOAT) / SUM (total_sales) OVER ()) * 100,2), '%') AS percentages_of_total
FROM category_sales
order by total_sales DESC

--data segmentation
--segmenting products into cost ranges and count how many products fall into each segment.


WITH product_segments AS (
SELECT
product_key,
product_name,
cost,
CASE WHEN cost < 100 THEN 'below 100'
     WHEN cost BETWEEN 100 AND 500 THEN '100-500'
	 WHEN cost BETWEEN 500 AND 1000 THEN  '500-1000'
	 ELSE 'Above 1000'
END cost_range
FROM gold.dim_products)

SELECT 
cost_range,
COUNT(product_key) AS total_products
FROM product_segments
GROUP BY cost_range
ORDER BY total_products DESC

--GROUPING CUSTOMERS INTO THREE SEGMENTS BASED ON THEIR SPENDING BEHAVIOR:
--_VIP : at leat 12 months of history and spending more than $5000.
--_regular : at least 12 months of history but spending $5000 or less.
--_new : lifespan less than 12 months.
WITH customer_spending AS (
SELECT 
c.customer_key,
SUM(f.sales_amount) AS total_spending,
MIN(order_date) AS first_order,
MAX(order_date) AS last_order,
DATEDIFF (month, MIN(order_date), MAX(order_date)) AS lifespan
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON f.customer_key = c.customer_key
GROUP BY c.customer_key
)

SELECT 
customer_segment,
COUNT(customer_key) AS total_customers
FROM(

SELECT 
customer_key,
CASE WHEN lifespan >= 12 AND total_spending > 5000 THEN 'VIP'
     WHEN LIFESPAN >= 12 AND total_spending <= 5000 THEN 'regular'
	 ELSE 'NEW'
END customer_segment
FROM customer_spending) t
GROUP BY customer_segment 
ORDER BY total_customers DESC




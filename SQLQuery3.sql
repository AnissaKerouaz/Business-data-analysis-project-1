/* Product Report


purpose: this report consolidates key product metrics and behaviors.

Highlights:
     1. gathers essential fields such as product name, category, subcategory and cost.
	 2. segments products by revenue to identify high-performers, mid-range or low performers.
	 3. aggregates product-level metrics:
	    -lifespan (in months)
		-total orders
		-total customers(unique)
		-total sales
		-total quantity sold
		-average selling price
		
	 4. Calculates valuable KPIs:
	    -recency (months since last sale)
		-average order revenue (AOR)
		-average monthly revenue
*/
CREATE VIEW gold.report_products AS (

WITH base_query AS(
/* base query : Retrieves core columns from fact_sales and dim_products
*/
SELECT 
f.order_number,
f.order_date,
f.customer_key,
f.sales_amount,
f.quantity,
p.product_key,
p.product_name,
p.category,
p.subcategory,
p.cost

FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
 ON f.product_key = p.product_key
WHERE order_date IS NOT NULL 
),

product_aggregations AS (
/* product aggregations : summarizes key metrics at the product level
*/
SELECT 
product_key,
product_name,
category,
subcategory,
cost,
DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan,
MAX(order_date) AS last_sale_date,
COUNT(DISTINCT order_number) AS total_orders,
COUNT(DISTINCT customer_key) AS total_customers,
SUM(sales_amount) AS total_sales,
SUM(quantity) AS total_quantity,
ROUND(AVG(CAST(sales_amount AS FLOAT) / NULLIF(quantity,0)),1) AS avg_selling_price

FROM base_query
GROUP BY 
product_key,
product_name,
category,
subcategory,
cost 
)

/* final query: KPIs */
SELECT 
product_key,
product_name,
category,
subcategory,
cost,
last_sale_date,
DATEDIFF(MONTH, last_sale_date, GETDATE()) AS recency_in_months,
CASE WHEN total_sales > 50000 THEN 'high-performer'
     WHEN total_sales >=10000 THEN 'mid-range'
	 ELSE 'low-perfomer'
END AS product_segment,
lifespan,
total_orders,
total_sales,
total_quantity,
total_customers,
avg_selling_price,

--Average order revenue AOR KPI:
CASE WHEN total_orders = 0 THEN 0
     ELSE total_sales / total_orders
END AS avg_order_revenue,

--Average monthly revenue
CASE WHEN lifespan = 0 THEN total_sales
     ELSE total_sales / lifespan 
END AS avg_monthly_revenue
FROM product_aggregations

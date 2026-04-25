/*--------------------------------------------------------------------------------------------------------------------------------------------------------
E-COMMERCE E.D.A USING ADVANCED SQL: Common Table Expression(CTE), Nested CTE, Window Functions,Aggregate Functions,sub queries,Reports 
--------------------------------------------------------------------------------------------------------------------------------------------------------*/

/* Question:  Analyze the sales performance over time*/
--  sales performance over the years
SELECT
YEAR(order_date) as order_year,
SUM(sales_amount) as total_sales,
COUNT(DISTINCT customer_key) as total_customers,
SUM(quantity) as total_quantity
FROM DataWarehouse_Portfolio1..fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date)
ORDER BY YEAR(order_date);

-- Sales performance over the month
SELECT
MONTH(order_date) as order_month,
SUM(sales_amount) as total_sales,
COUNT(DISTINCT customer_key) as total_customers,
SUM(quantity) as total_quantity
FROM DataWarehouse_Portfolio1..fact_sales
WHERE order_date IS NOT NULL
GROUP BY MONTH(order_date)
ORDER BY MONTH(order_date);

-- sales performance over the years and months
SELECT
DATETRUNC(month, order_date) as order_month,
SUM(sales_amount) as total_sales,
COUNT(DISTINCT customer_key) as total_customers,
SUM(quantity) as total_quantity
FROM DataWarehouse_Portfolio1..fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(month, order_date)
ORDER BY DATETRUNC(month, order_date);

/*---------------------------------------------------------------------------------------------------------------------------------------------------------
 Question : How many new customers were added each year
-----------------------------------------------------------------------------------------------------------------------------------------------------------*/
SELECT
DATETRUNC(Year, create_date) as create_year,
COUNT(customer_key) as total_customer
FROM DataWarehouse_Portfolio1..dim_customers
GROUP BY DATETRUNC(Year, create_date)
ORDER BY DATETRUNC(Year, create_date);

/*---------------------------------------------------------------------------------------------------------------------------------------------------------
Question: what is the average revenue per order
---------------------------------------------------------------------------------------------------------------------------------------------------------*/
SELECT
DATETRUNC(month, order_date) as order_month,
SUM(sales_amount) / COUNT(DISTINCT order_number) as Average_revenue_per_order
FROM DataWarehouse_Portfolio1..fact_sales
WHERE order_date IS NOT NULL 
GROUP BY DATETRUNC(month, order_date)
ORDER BY DATETRUNC(month, order_date);


/*-------------------------------------------------------------------------------------------------------------------------------------------------------
Question ; Calculate the total sales per month and the running total of sales over time 
--------------------------------------------------------------------------------------------------------------------------------------------------------*/
SELECT
order_date,
total_sales,
--window function
SUM(total_sales) OVER(PARTITION BY order_date ORDER BY order_date) AS running_total_sales
FROM
(
SELECT
DATETRUNC(Month, order_date) AS order_date,
SUM(sales_amount) AS total_sales
FROM DataWarehouse_Portfolio1..fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(Month, order_date)
) t ;

/*-------------------------------------------------------------------------------------------------------------------------------------------------------
Question : Calculate the Average Price per month and the Moving Average over time
---------------------------------------------------------------------------------------------------------------------------------------------------------*/
SELECT
order_date,
avg_price,
-- window function
AVG(avg_price) OVER( ORDER BY order_date) AS moving_average_price
FROM
(
SELECT
DATETRUNC(month, order_date) AS order_date,
AVG(price) AS avg_price
FROM DataWarehouse_Portfolio1..fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(Month, order_date)
) t 


/*---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- 
Question:  Analyze the yearly performance of products by comparing their sales to both the average sales performance of the product and the previous year's sales
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/

-- yearly performance of products by their sales
SELECT
YEAR(f.order_date) AS order_year,
p.product_name,
SUM(f.sales_amount) AS current_sales
FROM DataWarehouse_Portfolio1..fact_sales f
LEFT JOIN DataWarehouse_Portfolio1..dim_products p
ON f.product_key = p.product_key
WHERE f.order_date IS NOT NULL
GROUP BY
YEAR(f.order_date),
p.product_name;


--Yearly performance of products by comparing their sales to the average sales performance of the product
-- CTE
WITH yearly_product_sales AS
(
SELECT
YEAR(f.order_date) AS order_year,
p.product_name,
SUM(f.sales_amount) AS current_sales
FROM DataWarehouse_Portfolio1..fact_sales f
LEFT JOIN DataWarehouse_Portfolio1..dim_products p
ON f.product_key = p.product_key
WHERE f.order_date IS NOT NULL
GROUP BY
YEAR(f.order_date),
p.product_name
)
SELECT
order_year,
product_name,
current_sales,
AVG(current_sales) OVER(PARTITION BY product_name) AS avg_sales,
-- comparing the sales to the average sales performance of the product
current_sales - AVG(current_sales) OVER(PARTITION BY product_name) AS difference_Avg ,
CASE WHEN current_sales - AVG(current_sales) OVER(PARTITION BY product_name) > 0 THEN 'Above Avg'
     WHEN current_sales - AVG(current_sales) OVER(PARTITION BY product_name) < 0 THEN 'Below Avg'
     ELSE 'Avg'
END Avg_change,
--comparing the sales to the previous Year's performance (Year-Over-Year Analysis)
LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) AS previous_year_sales,
CASE WHEN current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) > 0  THEN 'Increase'
     WHEN current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY order_year) < 0  THEN 'Decrease'
     ELSE 'No change'
END Diff_in_CurrentYear_and_PreviousYear
FROM yearly_product_sales
ORDER BY product_name, order_year;


/*---------------------------------------------------------------------------------------------------------------------------------------------------------
Question: Identify the top performing products categories as percentage of total sales? 
-----------------------------------------------------------------------------------------------------------------------------------------------------------*/
WITH category_sales AS
(
SELECT
category,
SUM(sales_amount) total_sales
FROM DataWarehouse_Portfolio1..fact_sales f
LEFT JOIN DataWarehouse_Portfolio1..dim_products p
ON p.product_key = f.product_key
GROUP BY category
)
SELECT
category,
total_sales,
SUM(total_sales) OVER() overall_sales,
CONCAT(ROUND((CAST (total_sales AS FLOAT) / SUM(total_sales) OVER ()) * 100,2), '%') AS Percentage_of_total
FROM category_sales
ORDER BY total_sales DESC


/*----------------------------------------------------------------------------------------------------------------------------------------------------------
Question : Segment products into cost ranges and count how many products fall into each segments 
---------------------------------------------------------------------------------------------------------------------------------------------------------*/
-- segment products into cost ranges
SELECT
product_key,
product_name,
cost,
CASE WHEN cost < 100 THEN 'Below 100'
     WHEN cost BETWEEN 100 AND 500 THEN '100-500'
     WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
     ELSE 'Above 1000'
END cost_range
FROM DataWarehouse_Portfolio1..dim_products;

-- Segment products into cost ranges and count how many products fall into each segments
WITH product_segments AS
(
SELECT
product_key,
product_name,
cost,
CASE WHEN cost < 100 THEN 'Below 100'
     WHEN cost BETWEEN 100 AND 500 THEN '100-500'
     WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
     ELSE 'Above 1000'
END cost_range
FROM DataWarehouse_Portfolio1..dim_products
)
SELECT
cost_range,
COUNT(product_key) AS total_products
FROM product_segments
GROUP BY cost_range
ORDER BY total_products DESC;

/*---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Question: Group ustoemrs into three segments based on their spending behaviour:
             - VIP: customers wit at least 12 months of history and spending more than $5000
             -Regular: customers with at least 12 months of history but spending $5000 or less
             - New : customers with a lifespan less than 12months.
And find the total number of customers by each group 
--------------------------------------------------------------------------------------------------------------------------------------------------------------*/
-- Grouping the customers based on their spending behaviours and lifespan
SELECT
c.customer_key,
SUM(f.sales_amount) AS total_spending,
MIN(f.order_date) AS first_order,
MAX(f.order_date) AS 'last order',
DATEDIFF( month, MIN(f.order_date), MAX(order_date)) AS lifespan
FROM DataWarehouse_Portfolio1..fact_sales f
LEFT JOIN DataWarehouse_Portfolio1..dim_customers c
ON f.customer_key = c.customer_key
GROUP BY c.customer_key;

-- Grouping the customers into three segments based on their spending behaviours and lifespan
-- CTE
WITH customer_spending AS
(
SELECT
c.customer_key,
SUM(f.sales_amount) AS total_spending,
MIN(f.order_date) AS first_order,
MAX(f.order_date) AS 'last order',
DATEDIFF( month, MIN(f.order_date), MAX(order_date)) AS lifespan
FROM DataWarehouse_Portfolio1..fact_sales f
LEFT JOIN DataWarehouse_Portfolio1..dim_customers c
ON f.customer_key = c.customer_key
GROUP BY c.customer_key
)
SELECT
customer_key,
total_spending,
lifespan,
CASE WHEN lifespan >= 12 AND total_spending > 5000 THEN 'VIP'
     WHEN lifespan >= 12 AND total_spending <= 5000 THEN 'Regular'
     ELSE 'New'
END customer_segment
FROM customer_spending;

-- Group customers into three segments based on their spending behaviour and find the total number of customers by each group
WITH customer_spending AS
(
SELECT
c.customer_key,
SUM(f.sales_amount) AS total_spending,
MIN(f.order_date) AS first_order,
MAX(f.order_date) AS 'last order',
DATEDIFF( month, MIN(f.order_date), MAX(order_date)) AS lifespan
FROM DataWarehouse_Portfolio1..fact_sales f
LEFT JOIN DataWarehouse_Portfolio1..dim_customers c
ON f.customer_key = c.customer_key
GROUP BY c.customer_key
)

SELECT
customer_segment,
COUNT(customer_key) AS total_customers
FROM 
-- subquery
  (
   SELECT
   customer_key,
   total_spending,
   lifespan,
   CASE WHEN lifespan >= 12 AND total_spending > 5000 THEN 'VIP'
        WHEN lifespan >= 12 AND total_spending <= 5000 THEN 'Regular'
        ELSE 'New'
   END customer_segment
   FROM customer_spending
   ) AS t
GROUP BY customer_segment
ORDER BY total_customers DESC;

/*-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
  CUSTOMERS' REPORT
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Purpose : This report consolidates key customer metrics and behaviour

Highlights:
   1. Extract key fields such as names, ages, and transaction details.
   2. Aggregate customer-level metrics:
        - total orders
        - total sales
        - total quantity
        - total products
        - lifespan (in months)
    3. Segment customers into categories (VIP,Regular,New) and age group
    4. calculate valuable KPIs:
        - recency (months since last order)
        - average order value 
        - average monthly spend
  
--------------------------------------------------------------------------------------------------------------------------------------------------------
-- (1) Base Query ; Extract key fields such as names, ages, and transaction details.
-------------------------------------------------------------------------------------------------------------------------------------------------------*/
-- Nested Non-Recursive CTE  

WITH base_query AS
(
SELECT
f.order_number,
f.product_key,
f.order_date,
f.sales_amount,
f.quantity,
c.customer_key,
c.customer_number,
CONCAT(c.first_name, ' ',c.last_name) AS customer_name,
c.birthdate,
DATEDIFF(year, c.birthdate, GETDATE()) age
FROM  DataWarehouse_Portfolio1..fact_sales  f 
LEFT JOIN DataWarehouse_Portfolio1..dim_customers c
ON c.customer_key = f.customer_key
WHERE order_date IS NOT NULL 
)

,customer_aggregation AS
/*---------------------------------------------------------------------------
2) Customer Aggregations: Summarizes key metrics 
---------------------------------------------------------------------------*/
(
SELECT
  customer_key,
  customer_number,
  customer_name,
  age,
  COUNT(DISTINCT order_number)AS total_orders,
  SUM(sales_amount) AS total_sales,
  SUM(quantity) AS total_quantity,
  COUNT( DISTINCT product_key) AS total_products,
  MAX(order_date) AS last_order_date,
  DATEDIFF(Month, MIN(order_date),MAX(order_date)) AS lifespan
FROM base_query
GROUP BY
customer_key,
customer_number,
customer_name,
age
)
/*---------------------------------------------------------------------------
  3) Final Query: Combines all customer's report into one output
---------------------------------------------------------------------------*/
SELECT
customer_key,
customer_number,
customer_name,
age,
CASE WHEN age < 20 THEN 'under 20'
     WHEN age BETWEEN 20 AND 29 THEN '20-29'
     WHEN age BETWEEN 30 AND 39 THEN '30-39'
     WHEN age BETWEEN 40 AND 49 THEN '40-49'
     ELSE '50 and Above'
END AS age_group,
-- Segment customers into categories (VIP ,  Regular, New) and age groups
CASE WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
     WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
     ELSE 'New'
END customer_segment,
last_order_date,
DATEDIFF(Month, last_order_date, GETDATE()) AS recency,
total_orders,
total_sales,
total_quantity,
total_products,
last_order_date,
lifespan,
-- compute average order value (AVO)
CASE WHEN total_sales = 0 THEN 0
     ELSE total_sales / total_orders
END AS avg_order_value,
-- compute average monthly spend
CASE WHEN lifespan = 0 THEN total_sales
     ELSE total_sales / lifespan
END AS avg_monthly_spend
FROM customer_aggregation;


/*---------------------------------------------------------------------------------------------------------------------------------------------------
PRODUCT REPORT
-----------------------------------------------------------------------------------------------------------------------------------------------------
Purpose : This report consolidates key product metrics and behaviours.

Highlights :
    1. Extract key fields such as product name, category, subcategory and cost.
    2. Aggregates product-level metrics:
       - total orders
       - total sales
       - total quantity sold
       - total customers(unique)
       - lifespan (in months)
    3. Segments products by revenue to identify High-Performers Mid-Range, or  Low-Performers.
    4. Calculates valuable KPIs:
       - recency (month since last sales)
       - average order revenue (ADR)
       - average monthly revenue
-----------------------------------------------------------------------------------------------------------------------------------------------------
1) Base Query: Extract key fields such as product name, category, subcategory and cost.
-----------------------------------------------------------------------------------------------------------------------------------------------------*/
-- Nested Non-Recursive CTE  
WITH base_query AS
(
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
 FROM DataWarehouse_Portfolio1..fact_sales f
 LEFT JOIN DataWarehouse_Portfolio1..dim_products p
 ON f.product_key = p.product_key
 WHERE order_date IS NOT NULL  -- only consider valid sales dates
)

,product_aggregations AS (
/*---------------------------------------------------------------------------
2) Product Aggregations: Summarizes key metrics at the product level
---------------------------------------------------------------------------*/
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
	ROUND(AVG(CAST(sales_amount AS FLOAT) / NULLIF(quantity, 0)),1) AS avg_selling_price
FROM base_query

GROUP BY
    product_key,
    product_name,
    category,
    subcategory,
    cost
)

/*---------------------------------------------------------------------------
  3) Final Query: Combines all product results into one output
---------------------------------------------------------------------------*/
SELECT 
	product_key,
	product_name,
	category,
	subcategory,
	cost,
	last_sale_date,
	DATEDIFF(MONTH, last_sale_date, GETDATE()) AS recency_in_months,
    -- Segment products by revenue to identify High-Performers Mid-Range, or  Low-Performers
	CASE
		WHEN total_sales > 50000 THEN 'High-Performer'
		WHEN total_sales >= 10000 THEN 'Mid-Range'
		ELSE 'Low-Performer'
	END AS product_segment,
	lifespan,
	total_orders,
	total_sales,
	total_quantity,
	total_customers,
	avg_selling_price,
	-- Average Order Revenue (AOR)
	CASE 
		WHEN total_orders = 0 THEN 0
		ELSE total_sales / total_orders
	END AS avg_order_revenue,

	-- Average Monthly Revenue
	CASE
		WHEN lifespan = 0 THEN total_sales
		ELSE total_sales / lifespan
	END AS avg_monthly_revenue

FROM product_aggregations 

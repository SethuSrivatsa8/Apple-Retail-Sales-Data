-- Apple Sales Project - 1M rows sales datasets

SELECT * FROM category;
SELECT * FROM products;
SELECT * FROM stores;
SELECT * FROM sales;
SELECT * FROM warranty;

SELECT DISTINCT repair_status FROM warranty;
SELECT COUNT(*) FROM sales;

-- Improving Query Performance 

-- execution time before indexing - 56.768ms

EXPLAIN ANALYZE
SELECT * FROM sales
WHERE product_id ='P-44'

CREATE INDEX sales_product_id ON sales(product_id);
CREATE INDEX sales_store_id ON sales(store_id);
CREATE INDEX sales_sale_date ON sales(sale_date);
CREATE INDEX idx_sales_store_id ON sales(store_id);
CREATE INDEX idx_sales_quantity ON sales(quantity);

-- execution time after indexing - 1.960ms

-- Business Problems

-- 1. Find the number of stores in each country.

SELECT 
	country,
	COUNT(store_id) as total_stores
FROM stores
GROUP BY 1
ORDER BY 2 DESC

-- Q.2 Calculate the total number of units sold by each store.

SELECT 
	s.store_id,
	st.store_name,
	SUM(s.quantity) as total_unit_sold
FROM sales as s
JOIN
stores as st
ON st.store_id = s.store_id
GROUP BY 1, 2
ORDER BY 3 DESC

-- Q.3 Identify how many sales occurred in December 2023.


SELECT 
	COUNT(sale_id) as total_sale 
FROM sales
WHERE TO_CHAR(sale_date, 'MM-YYYY') = '12-2023'

-- Q.4 Determine how many stores have never had a warranty claim filed.

SELECT COUNT(*) FROM stores
WHERE store_id NOT IN (
						SELECT 
							DISTINCT store_id
						FROM sales as s
						RIGHT JOIN warranty as w
						ON s.sale_id = w.sale_id
						);

-- Q.5 Calculate the percentage of warranty claims marked as "Warranty Void".

SELECT 
	ROUND
		(COUNT(claim_id)/
						(SELECT COUNT(*) FROM warranty)::numeric 
		* 100, 
	2)as warranty_void_percentage
FROM warranty
WHERE repair_status = 'Warranty Void'

-- Q.6 Identify which store had the highest total units sold in the last year.

SELECT 
	s.store_id,
	st.store_name,
	SUM(s.quantity)
FROM sales as s
JOIN stores as st
ON s.store_id = st.store_id
WHERE sale_date >= (CURRENT_DATE - INTERVAL '1 year')
GROUP BY 1, 2
ORDER BY 3 DESC
LIMIT 1

-- Q.7 Count the number of unique products sold in the last year.

SELECT 
	COUNT(DISTINCT product_id)
FROM sales
WHERE sale_date >= (CURRENT_DATE - INTERVAL '1 year')

-- Q.8 Find the average price of products in each category.

SELECT 
	p.category_id,
	c.category_name,
	AVG(p.price) as avg_price
FROM products as p
JOIN 
category as c
ON p.category_id = c.category_id
GROUP BY 1, 2
ORDER BY 3 DESC

-- Q.9 How many warranty claims were filed in 2020?

SELECT 
	COUNT(*) as warranty_claim
FROM warranty
WHERE EXTRACT(YEAR FROM claim_date) = 2020

-- Q.10 For each store, identify the best-selling day based on highest quantity sold.

SELECT  * 
FROM
(
	SELECT 
		store_id,
		TO_CHAR(sale_date, 'Day') as day_name,
		SUM(quantity) as total_unit_sold,
		RANK() OVER(PARTITION BY store_id ORDER BY SUM(quantity) DESC) as rank
	FROM sales
	GROUP BY 1, 2
) as t1
WHERE rank = 1

-- Q.11 Identify the least selling product in each country for each year based on total units sold.


WITH product_rank
AS
(
SELECT 
	st.country,
	p.product_name,
	SUM(s.quantity) as total_qty_sold,
	RANK() OVER(PARTITION BY st.country ORDER BY SUM(s.quantity)) as rank
FROM sales as s
JOIN 
stores as st
ON s.store_id = st.store_id
JOIN
products as p
ON s.product_id = p.product_id
GROUP BY 1, 2
)
SELECT 
* 
FROM product_rank
WHERE rank = 1

-- Q.12 Calculate how many warranty claims were filed within 180 days of a product sale.

SELECT 
	COUNT(*)
FROM warranty as w
LEFT JOIN 
sales as s
ON s.sale_id = w.sale_id
WHERE 
	w.claim_date - sale_date <= 180

--Q.13  Determine how many warranty claims were filed for products launched in the last two years.


SELECT 
	p.product_name,
	COUNT(w.claim_id) as no_claim,
	COUNT(s.sale_id)
FROM warranty as w
RIGHT JOIN
sales as s 
ON s.sale_id = w.sale_id
JOIN products as p
ON p.product_id = s.product_id
WHERE p.launch_date >= CURRENT_DATE - INTERVAL '2 years'
GROUP BY 1
HAVING COUNT(w.claim_id) > 0

-- Q.14 List the months in the last three years where sales exceeded 5,000 units in the USA.

SELECT 
	TO_CHAR(sale_date, 'MM-YYYY') as month,
	SUM(s.quantity) as total_unit_sold
FROM sales as s
JOIN 
stores as st
ON s.store_id = st.store_id
WHERE 
	st.country = 'USA'
	AND
	s.sale_date >= CURRENT_DATE - INTERVAL '3 year'
GROUP BY 1
HAVING SUM(s.quantity) > 5000


-- Q.15 Identify the product category with the most warranty claims filed in the last two years.

SELECT 
	c.category_name,
	COUNT(w.claim_id) as total_claims
FROM warranty as w
LEFT JOIN
sales as s
ON w.sale_id = s.sale_id
JOIN products as p
ON p.product_id = s.product_id
JOIN 
category as c
ON c.category_id = p.category_id
WHERE 
	w.claim_date >= CURRENT_DATE - INTERVAL '2 year'
GROUP BY 1


-- Q.16 Determine the percentage chance of receiving warranty claims after each purchase for each country!

SELECT 
	country,
	total_unit_sold,
	total_claim,
	COALESCE(total_claim::numeric/total_unit_sold::numeric * 100, 0)
	as risk
FROM
(SELECT 
	st.country,
	SUM(s.quantity) as total_unit_sold,
	COUNT(w.claim_id) as total_claim
FROM sales as s
JOIN stores as st
ON s.store_id = st.store_id
LEFT JOIN 
warranty as w
ON w.sale_id = s.sale_id
GROUP BY 1) t1
ORDER BY 4 DESC

-- Q.17 Analyze the year-by-year growth ratio for each store.

WITH yearly_sales
AS
(
	SELECT 
		s.store_id,
		st.store_name,
		EXTRACT(YEAR FROM sale_date) as year,
		SUM(s.quantity * p.price) as total_sale
	FROM sales as s
	JOIN
	products as p
	ON s.product_id = p.product_id
	JOIN stores as st
	ON st.store_id = s.store_id
	GROUP BY 1, 2, 3
	ORDER BY 2, 3 
),
growth_ratio
AS
(
SELECT 
	store_name,
	year,
	LAG(total_sale, 1) OVER(PARTITION BY store_name ORDER BY year) as last_year_sale,
	total_sale as current_year_sale
FROM yearly_sales
)

SELECT 
	store_name,
	year,
	last_year_sale,
	current_year_sale,
	ROUND(
			(current_year_sale - last_year_sale)::numeric/
							last_year_sale::numeric * 100
	,3) as growth_ratio
FROM growth_ratio
WHERE 
	last_year_sale IS NOT NULL
	AND 
	YEAR <> EXTRACT(YEAR FROM CURRENT_DATE)

-- Q.18 Calculate the correlation between product price and warranty claims for 
-- products sold in the last five years, segmented by price range.

SELECT 
	
	CASE
		WHEN p.price < 500 THEN 'Less Expenses Product'
		WHEN p.price BETWEEN 500 AND 1000 THEN 'Mid Range Product'
		ELSE 'Expensive Product'
	END as price_segment,
	COUNT(w.claim_id) as total_Claim
FROM warranty as w
LEFT JOIN
sales as s
ON w.sale_id = s.sale_id
JOIN 
products as p
ON p.product_id = s.product_id
WHERE claim_date >= CURRENT_DATE - INTERVAL '5 year'
GROUP BY 1


-- Q.19 Identify the store with the highest percentage of "Paid Repaired" claims relative to total claims filed


WITH paid_repair
AS
(SELECT 
	s.store_id,
	COUNT(w.claim_id) as paid_repaired
FROM sales as s
RIGHT JOIN warranty as w
ON w.sale_id = s.sale_id
WHERE w.repair_status = 'Paid Repaired'
GROUP BY 1
),

total_repaired
AS
(SELECT 
	s.store_id,
	COUNT(w.claim_id) as total_repaired
FROM sales as s
RIGHT JOIN warranty as w
ON w.sale_id = s.sale_id
GROUP BY 1)

SELECT 
	tr.store_id,
	st.store_name,
	pr.paid_repaired,
	tr.total_repaired,
	ROUND(pr.paid_repaired::numeric/
			tr.total_repaired::numeric * 100
		,2) as percentage_paid_repaired
FROM paid_repair as pr
JOIN 
total_repaired tr
ON pr.store_id = tr.store_id
JOIN stores as st
ON tr.store_id = st.store_id


-- Q.20 Write a query to calculate the monthly running total of sales for each store
-- over the past four years and compare trends during this period.

WITH monthly_sales
AS
(SELECT 
	store_id,
	EXTRACT(YEAR FROM sale_date) as year,
	EXTRACT(MONTH FROM sale_date) as month,
	SUM(p.price * s.quantity) as total_revenue
FROM sales as s
JOIN 
products as p
ON s.product_id = p.product_id
GROUP BY 1, 2, 3
ORDER BY 1, 2,3
)
SELECT 
	store_id,
	month,
	year,
	total_revenue,
	SUM(total_revenue) OVER(PARTITION BY store_id ORDER BY year, month) as running_total
FROM monthly_sales

-- Q.21 
-- Analyze product sales trends over time, segmented into key periods: from launch to 6 months, 6-12 months, 12-18 months, and beyond 18 months.

SELECT 
	p.product_name,
	CASE 
		WHEN s.sale_date BETWEEN p.launch_date AND p.launch_date + INTERVAL '6 month' THEN '0-6 month'
		WHEN s.sale_date BETWEEN  p.launch_date + INTERVAL '6 month'  AND p.launch_date + INTERVAL '12 month' THEN '6-12' 
		WHEN s.sale_date BETWEEN  p.launch_date + INTERVAL '12 month'  AND p.launch_date + INTERVAL '18 month' THEN '6-12'
		ELSE '18+'
	END as plc,
	SUM(s.quantity) as total_qty_sale
	
FROM sales as s
JOIN products as p
ON s.product_id = p.product_id
GROUP BY 1, 2
ORDER BY 1, 3 DESC

--Q.22 
--Identify products with consecutive warranty claims within 30 days

WITH claim_sequences AS (
    SELECT 
        p.product_id,
        w.claim_date,
        LEAD(w.claim_date) OVER (
            PARTITION BY p.product_id 
            ORDER BY w.claim_date
        ) AS next_claim_date,
        (LEAD(w.claim_date) OVER (
            PARTITION BY p.product_id 
            ORDER BY w.claim_date
        ) - w.claim_date) AS days_between_claims
    FROM warranty w
    JOIN sales s ON w.sale_id = s.sale_id
    JOIN products p ON s.product_id = p.product_id
)
SELECT 
    product_id,
    COUNT(*) AS sequential_claims_count
FROM claim_sequences
WHERE days_between_claims <= 30  
GROUP BY product_id
ORDER BY sequential_claims_count DESC;

-- Q 23. Display Dynamic Price Tier Analysis with Rolling Metrics by categorizing products into dynamic price tiers and calculating 6-month rolling revenue metrics.

WITH price_tiers AS (
    SELECT 
        product_id,
        price,
        WIDTH_BUCKET(price, 0, 3000, 6) AS price_tier
    FROM products
),
monthly_sales AS (
    SELECT 
        s.product_id,
        DATE_TRUNC('month', s.sale_date) AS sale_month,
        SUM(s.quantity * p.price) AS revenue
    FROM sales s
    JOIN products p ON s.product_id = p.product_id
    GROUP BY 1, 2
)
SELECT 
    pt.price_tier,
    ms.sale_month,
    AVG(ms.revenue) OVER (PARTITION BY pt.price_tier ORDER BY ms.sale_month ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS rolling_6mo_avg_revenue,
    SUM(ms.revenue) OVER (PARTITION BY pt.price_tier ORDER BY ms.sale_month) AS cumulative_revenue
FROM monthly_sales ms
JOIN price_tiers pt ON ms.product_id = pt.product_id;

-- Q24.
-- Design a function, analyze_store_hierarchy, that identifies top-performing stores and their sphere of influence based on sales quantity and warranty claims

CREATE OR REPLACE FUNCTION analyze_store_hierarchy(
    top_stores_percentage DECIMAL DEFAULT 0.1,
    max_recursion_level INT DEFAULT 5,
    sales_threshold INT DEFAULT 10,
    consider_warranty BOOLEAN DEFAULT FALSE 
)
RETURNS TABLE (
    top_performing_store VARCHAR(5),
    influenced_stores BIGINT,
    total_units_sold BIGINT
) AS $$
DECLARE
    current_level INT := 2;
BEGIN
    -- Create temporary table
    CREATE TEMP TABLE IF NOT EXISTS store_hierarchy (
        store_id VARCHAR(5),
        store_name VARCHAR(30),
        city VARCHAR(25),
        country VARCHAR(25),
        top_performing_store VARCHAR(5),
        level INT
    ) ON COMMIT DROP;

    -- Insert initial set of top-performing stores
    INSERT INTO store_hierarchy (store_id, store_name, city, country, top_performing_store, level)
    SELECT 
        s.store_id,
        s.store_name,
        s.city,
        s.country,
        s.store_id AS top_performing_store,
        1 AS level
    FROM stores s
    JOIN (
        SELECT store_id, SUM(quantity) as total_sales
        FROM sales
        GROUP BY store_id
        ORDER BY total_sales DESC
        LIMIT (SELECT COUNT(*) * top_stores_percentage FROM stores)
    ) top_stores ON s.store_id = top_stores.store_id;

    -- Iteratively insert influenced stores
    WHILE current_level <= max_recursion_level LOOP
        INSERT INTO store_hierarchy (store_id, store_name, city, country, top_performing_store, level)
        SELECT DISTINCT
            s.store_id,
            s.store_name,
            s.city,
            s.country,
            sh.top_performing_store,
            current_level AS level
        FROM stores s
        JOIN sales sa ON s.store_id = sa.store_id
        JOIN store_hierarchy sh ON sa.store_id <> sh.store_id
        WHERE sa.quantity > sales_threshold
          AND NOT EXISTS (
              SELECT 1 FROM store_hierarchy WHERE store_id = s.store_id
          )
           -- Additional condition based on warranty claims
          AND CASE WHEN consider_warranty THEN EXISTS (
            SELECT 1
            FROM warranty w
            JOIN sales s2 ON w.sale_id = s2.sale_id
            WHERE s2.store_id = s.store_id
          ) ELSE TRUE END;

        current_level := current_level + 1;
    END LOOP;

    -- Query the temporary table to get the results
    RETURN QUERY
    SELECT 
        sh.top_performing_store,
        COUNT(DISTINCT sh.store_id) AS influenced_stores,
        SUM(sa.quantity) AS total_units_sold
    FROM store_hierarchy sh
    JOIN sales sa ON sh.store_id = sa.store_id
    GROUP BY sh.top_performing_store
    ORDER BY total_units_sold DESC;
END;
$$ LANGUAGE plpgsql;


SELECT * FROM analyze_store_hierarchy(
    top_stores_percentage := 0.15,    -- Top 15%
    max_recursion_level := 4,         -- Up to 4 levels
    sales_threshold := 20,           -- Sales > 20
    consider_warranty := TRUE          -- Only stores with warranty claims
);

--Q25. 
--Create a trigger that flags suspicious warranty claims using multiple conditions.

CREATE TABLE warranty_fraud_log (
    log_id SERIAL PRIMARY KEY,
    claim_id VARCHAR(10),
    reason VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION check_warranty_fraud()
RETURNS TRIGGER AS $$
BEGIN
    IF (NEW.claim_date - (SELECT sale_date FROM sales WHERE sale_id = NEW.sale_id)) > 365 THEN
        INSERT INTO warranty_fraud_log (claim_id, reason)
        VALUES (NEW.claim_id, 'Claim filed after warranty period');
    ELSIF (SELECT COUNT(*) FROM warranty WHERE sale_id = NEW.sale_id) > 3 THEN
        INSERT INTO warranty_fraud_log (claim_id, reason)
        VALUES (NEW.claim_id, 'Excessive claims for single purchase');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER fraud_detection_trigger
AFTER INSERT ON warranty
FOR EACH ROW EXECUTE FUNCTION check_warranty_fraud();

--Q26.
--Find products with above-average warranty claims in their price category using correlated subqueries

SELECT 
    p.product_id,
    p.product_name,
    p.price,
    (SELECT AVG(price) FROM products WHERE category_id = p.category_id) AS category_avg_price,
    COUNT(w.claim_id) AS total_claims,
    (SELECT AVG(claim_count) 
     FROM (SELECT COUNT(claim_id) AS claim_count 
           FROM warranty 
           JOIN sales USING (sale_id)
           GROUP BY product_id) AS sub) AS global_avg_claims
FROM products p
LEFT JOIN sales s ON p.product_id = s.product_id
LEFT JOIN warranty w ON s.sale_id = w.sale_id
GROUP BY p.product_id, p.product_name, p.price, p.category_id
HAVING COUNT(w.claim_id) > (
    SELECT AVG(claim_count) 
    FROM (SELECT COUNT(claim_id) AS claim_count 
          FROM warranty 
          JOIN sales USING (sale_id)
          JOIN products p2 USING (product_id)
          WHERE p2.category_id = p.category_id
          GROUP BY p2.product_id) AS cat_sub
);
--Q27.
--Identify products that initiate the most warranty claim propagations to other products sold in the same transaction within 90 days, using a recursive CTE.

WITH RECURSIVE WarrantyPropagation AS (
    -- Anchor member: Initial warranty claims
    SELECT 
        w.claim_id,
        s.sale_id,
        s.product_id,
        s.sale_date,
        w.claim_date
    FROM warranty w
    JOIN sales s ON w.sale_id = s.sale_id

    UNION ALL

    -- Recursive member: Find other products with claims within 90 days in the same sale
    SELECT
        w.claim_id,
        s.sale_id,
        s.product_id,
        s.sale_date,
        w.claim_date
    FROM warranty w
    JOIN sales s ON w.sale_id = s.sale_id
    JOIN WarrantyPropagation wp ON s.sale_id = wp.sale_id
    WHERE s.product_id <> wp.product_id  -- Avoid self-referencing
      AND w.claim_date BETWEEN wp.sale_date AND wp.sale_date + INTERVAL '90 days'
)
SELECT 
    product_id,
    COUNT(DISTINCT sale_id) AS propagated_claim_count
FROM WarrantyPropagation
GROUP BY product_id
ORDER BY propagated_claim_count DESC;

--Q28.Calculate a 7-day moving average of sales, but only considering weekdays

WITH daily_sales AS (
    SELECT
        sale_date,
        SUM(quantity) AS total_sales
    FROM sales
    GROUP BY sale_date
),
weekday_sales AS (
    SELECT
        sale_date,
        total_sales,
        EXTRACT(DOW FROM sale_date) AS day_of_week  -- 0=Sunday, 6=Saturday
    FROM daily_sales
    WHERE EXTRACT(DOW FROM sale_date) BETWEEN 1 AND 5  -- Weekdays only
)
SELECT
    sale_date,
    total_sales,
    AVG(total_sales) OVER (ORDER BY sale_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg_7day
FROM weekday_sales
ORDER BY sale_date;

--
--Q29.Identify products whose price is significantly different from the median price of products sold in the same city on the same day

SELECT
    s.sale_id,
    s.sale_date,
    p.product_id,
    p.product_name,
    p.price,
    city_median.median_price
FROM
    sales s
JOIN
    products p ON s.product_id = p.product_id
JOIN
    stores st ON s.store_id = st.store_id
CROSS JOIN LATERAL (
    SELECT
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY p2.price) AS median_price
    FROM
        sales s2
    JOIN
        products p2 ON s2.product_id = p2.product_id
    JOIN
    	stores st2 ON s2.store_id = st2.store_id
    WHERE
        s2.sale_date = s.sale_date
        AND st2.city = st.city
) AS city_median
WHERE ABS(p.price - city_median.median_price) > (0.2 * city_median.median_price) -- Price differs by more than 20% from median
ORDER BY s.sale_date, st.city;

--Q30.
--Identify product categories where the ratio of warranty claims for high-priced products (above the 75th percentile price) to the total number of claims in that category is exceptionally high.

WITH CategoryWarranty AS (
    SELECT
        p.category_id,
        COUNT(w.claim_id) AS total_claims,
        SUM(CASE WHEN p.price > price_threshold.threshold THEN 1 ELSE 0 END) AS high_price_claims
    FROM
        sales s
    JOIN
        products p ON s.product_id = p.product_id
    LEFT JOIN
        warranty w ON s.sale_id = w.sale_id
    CROSS JOIN (SELECT PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY price) AS threshold FROM products) AS price_threshold
    GROUP BY p.category_id
),
CategoryRatios AS (
    SELECT
        category_id,
        total_claims,
        high_price_claims,
        (high_price_claims::DECIMAL / total_claims) AS high_price_ratio,
        AVG((high_price_claims::DECIMAL / total_claims)) OVER () AS overall_avg_ratio -- Overall average ratio
    FROM CategoryWarranty
    WHERE total_claims > 0
)
SELECT
    c.category_name,
    cr.total_claims,
    cr.high_price_claims,
    cr.high_price_ratio
FROM CategoryRatios cr
JOIN category c ON cr.category_id = c.category_id
WHERE cr.high_price_ratio > (1.5 * cr.overall_avg_ratio)  -- Significantly higher than average
ORDER BY cr.high_price_ratio DESC;
--Q.31
--Identify which products act as 'Keystone Products', significantly increasing customer's likelihood of future warranty claims across their entire purchase history. Rank these products by the lift in claim rate compared to the baseline, considering customer-specific sales correlations.
WITH CustomerData AS (
    -- 1. Customer Identification using store + other criteria
    SELECT
        s.sale_id,
        s.product_id,
        s.sale_date,
        MD5(COALESCE(st.city, 'unknown') || COALESCE(st.country, 'unknown')) AS customer_id,
        st.store_id
    FROM sales s
    JOIN stores st ON s.store_id = st.store_id
),
WarrantyData AS (
    -- 2. Warranty Claims aggregated
    SELECT
        cd.customer_id,
        cd.store_id,
        cd.product_id,
        COUNT(w.claim_id) AS customer_claims
    FROM CustomerData cd
    LEFT JOIN warranty w ON cd.sale_id = w.sale_id
    GROUP BY cd.customer_id, cd.store_id, cd.product_id
),
SaleData AS (
    -- 3. Sale Data with total Units Sold and joins with sale
    SELECT
        cd.customer_id,
        cd.store_id,
        cd.product_id,
        COUNT(cd.sale_id) AS customer_sales,
        SUM(s.quantity) as units_sold
    FROM CustomerData cd
    JOIN sales s ON cd.sale_id = s.sale_id
    GROUP BY cd.customer_id, cd.store_id, cd.product_id
),
CustomerSummary AS (
    -- 4. Combines Sales with Warranty (all levels)
    SELECT
        sd.customer_id,
        sd.store_id,
        sd.product_id,
        sd.customer_sales,
        sd.units_sold,
        COALESCE(wd.customer_claims, 0) AS customer_claims
    FROM SaleData sd
    LEFT JOIN WarrantyData wd ON sd.customer_id = wd.customer_id AND sd.store_id = wd.store_id AND sd.product_id = wd.product_id
),
KeystoneAnalysis AS (
    -- 5. Analyzes products and identifies number of Customer who purchase
    SELECT
        p.product_id AS keystone_product_id,
        COUNT(DISTINCT CASE WHEN EXISTS (SELECT 1 FROM CustomerData cd WHERE cd.customer_id = cs.customer_id AND cd.product_id = p.product_id) THEN cs.customer_id ELSE NULL END) AS keystone_customer_count,
        AVG(cs.customer_claims::DECIMAL / NULLIF(cs.customer_sales, 0)) AS keystone_customer_claim_rate,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY cs.customer_claims::DECIMAL / NULLIF(cs.customer_sales, 0)) AS keystone_customer_claim_rate_median,
        AVG(cs.customer_sales) as keystone_customer_avg_sales,
        AVG(cs.customer_claims) as keystone_customer_avg_claims,
        REGR_SLOPE(cs.customer_claims, cs.units_sold) AS sales_claim_correlation  --Sales Correlation
    FROM products p, CustomerSummary cs
    WHERE p.product_id = cs.product_id --Add this link so the analysis only take products present
    GROUP BY p.product_id
),
BaselineData AS (
    -- 6. Calculates all number
    SELECT
        AVG(customer_claims::DECIMAL / NULLIF(customer_sales, 0)) AS baseline_claim_rate,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY customer_claims::DECIMAL / NULLIF(customer_sales, 0)) AS baseline_claim_rate_median,
        AVG(customer_sales) as baseline_customer_avg_sales,
        AVG(customer_claims) as baseline_customer_avg_claims,
        REGR_SLOPE(customer_claims, units_sold) AS sales_claim_correlation,
        COUNT(DISTINCT customer_id) AS total_customers
    FROM CustomerSummary
),
CombinedData AS (
    --7. Add lift
    SELECT
        ka.keystone_product_id,
        ka.keystone_customer_count,
        ka.keystone_customer_claim_rate,
        ka.keystone_customer_claim_rate_median,
        ka.keystone_customer_avg_sales,
        ka.keystone_customer_avg_claims,
        ka.sales_claim_correlation as keystone_sales_claim_correlation,
        bd.baseline_claim_rate,
        bd.baseline_claim_rate_median,
        bd.baseline_customer_avg_sales,
        bd.baseline_customer_avg_claims,
        bd.sales_claim_correlation as baseline_sales_claim_correlation,
        bd.total_customers as all_customers,
        CASE WHEN bd.baseline_claim_rate > 0 THEN (ka.keystone_customer_claim_rate - bd.baseline_claim_rate) / bd.baseline_claim_rate ELSE 0 END AS lift_over_baseline,
        CASE WHEN bd.baseline_claim_rate_median > 0 THEN (ka.keystone_customer_claim_rate_median - bd.baseline_claim_rate_median) / bd.baseline_claim_rate_median ELSE 0 END AS lift_over_baseline_median,
        (ka.keystone_customer_avg_sales  - bd.baseline_customer_avg_sales)  AS sales_vs_baseline,
        (ka.keystone_customer_avg_claims - bd.baseline_customer_avg_claims) AS claims_vs_baseline,
        ka.keystone_customer_avg_sales * ka.keystone_customer_claim_rate AS impact_score
    FROM KeystoneAnalysis ka
    CROSS JOIN BaselineData bd
)
SELECT
    keystone_product_id,
    lift_over_baseline,
    lift_over_baseline_median,
    sales_vs_baseline,
    claims_vs_baseline,
    RANK() OVER (ORDER BY lift_over_baseline DESC) as lift_rank,
    RANK() OVER (ORDER BY lift_over_baseline_median DESC) as lift_rank_median,
    RANK() OVER (ORDER BY sales_vs_baseline DESC) as sales_rank,
    RANK() OVER (ORDER BY claims_vs_baseline DESC) as claims_rank,
    RANK() OVER (ORDER BY impact_score DESC) as impact_rank
FROM CombinedData
ORDER BY lift_rank ASC

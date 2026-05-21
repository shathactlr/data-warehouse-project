/*

-- =================================================================================
-- Description: This script builds a Star Schema Data Warehouse Layer (Gold Layer).
--              It creates consolidated views for Dimensions and Facts by merging 
--              and cleaning data from the staging area (Silver Layer).
--
-- Components:
--  1. [Gold].[dim_customers] : Consolidates customer profiles, normalizes demographics 
--                              (e.g., gender fallback logic), and generates a surrogate key.
--  2. [Gold].[dim_products]  : Stores current active products by filtering out historical 
--                              data and joining product details with their categories.
--  3. [Gold].[fact_sales]    : Links sales transactions to the created dimensions (Customers 
--                              and Products) to enable business intelligence and reporting.
--
-- BI Readiness & Value:
--  - Plug-and-Play: Fully optimized for BI tools like Power BI and Tableau to automatically 
--                   detect relationships.
--  - High Performance: Eliminates complex joins, ensuring lightning-fast dashboard rendering.
--  - Source of Truth: Embedded business logic guarantees unified and accurate data insights.
-- =================================================================================

*/

--===================================================================
--  Create dimension : gold.dim_customers
--===================================================================

CREATE VIEW [Gold].[dim_customers] AS
SELECT
ROW_NUMBER() OVER (ORDER BY cst_id) AS customer_key,
	ci.cst_id AS custmer_id,
	ci.cst_Key AS custmer_number,
	ci.cst_firstname AS first_name,
	ci.cst_lastname AS last_name,
	ci.cst_marital_status AS marital_status,
	CASE WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr --CRM IS THE MASTER FOR GENDER INFO
		ELSE COALESCE(ca.gen, 'n/a')
	END AS gender,
	ci.cst_create_date AS create_date,
	ca.bdate AS birthdate,
	la.cntry AS country
from silver.crm_cust_info ci
LEFT JOIN Silver.erp_cust_az12 ca
ON			ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON		ci.cst_key = la.cid
GO


--===================================================================
--  Create dimension : gold.dim_products
--===================================================================

CREATE VIEW [Gold].[dim_products] AS
SELECT 
ROW_NUMBER() OVER (ORDER BY pn.prd_start_dt, pn.prd_key) AS product_key,
pn.prd_id AS product_id,
pn.prd_key AS product_number,
pn.prd_nm AS product_name,
pn.cat_id AS category_id,
pc.cat AS category, 
pc.subcat AS subcategory,
pc.maintenance,
pn.prd_cost AS product_cost,
pn.prd_line AS product_line,
pn.prd_start_dt AS start_date
FROM Silver.crm_prd_info pn
LEFT JOIN silver.erp_px_cat_g1v2 pc
ON pn.cat_id = pc.id
WHERE prd_end_dt IS NULL -- TO filter out all historical data
GO

--===================================================================
--  Create Fact : gold.fact_sales
--===================================================================

CREATE VIEW [Gold].[fact_sales] AS
SELECT 
sd.sls_ord_num AS order_number,
pr.product_key,
cu.customer_key,
sd.sls_order_dt AS order_date,
sd.sls_ship_dt AS shipping_date,
sd.sls_due_dt AS due_date,
sd.sls_sales AS sales_amount,
sd.sls_quantity AS quanity ,
sd.sls_price AS price
FROM Silver.crm_sales_details sd
LEFT JOIN gold.dim_products pr 
ON sd.sls_prd_key = pr.product_number
LEFT JOIN gold.dim_customers cu
ON sd.sls_cust_id = cu.custmer_id
GO

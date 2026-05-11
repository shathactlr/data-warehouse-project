/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure manages the ETL (Extract, Transform, Load) workflow 
    by migrating data from the 'bronze' schema to the 'silver' schema.

Actions Performed:
    - Extraction: Pulls raw data from CRM and ERP sources stored in Bronze.
    - Transformation: Executes data cleansing, string trimming, categorical 
      normalization, and deduplication to ensure high data quality.
    - Loading: Truncates and reloads structured tables in the Silver Layer, 
      serving as a reliable source for analytical reporting.

Usage Example:
    EXEC Silver.load_silver;
===============================================================================
*/

CREATE OR ALTER PROCEDURE Silver.load_silver AS
BEGIN
 

PRINT '---------------------------------';
PRINT 'Loading The Silver Layer';
PRINT '---------------------------------';

PRINT '---------------------------------';
PRINT 'Loading CRM Tables';
PRINT '---------------------------------';

	TRUNCATE TABLE Silver.crm_cust_info;
			PRINT '>> Inserting Data Into: silver.crm_cust_info';
			INSERT INTO Silver.crm_cust_info (
				cst_id, 
				cst_key, 
				cst_firstname, 
				cst_lastname, 
				cst_marital_status, 
				cst_gndr,
				cst_create_date
			)
			SELECT
				cst_id,
				cst_key,
				TRIM(cst_firstname) AS cst_firstname,
				TRIM(cst_lastname) AS cst_lastname,
				CASE 
					WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
					WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
					ELSE 'n/a'
				END AS cst_marital_status, -- Normalize marital status values to readable format
				CASE 
					WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
					WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
					ELSE 'n/a'
				END AS cst_gndr, -- Normalize gender values to readable format
				cst_create_date
			FROM (
				SELECT
					*,
					ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
				FROM bronze.crm_cust_info
				WHERE cst_id IS NOT NULL
			) t
			WHERE flag_last = 1; -- Select the most recent record per customer


			-- Loading silver.crm_prd_info
			TRUNCATE TABLE Silver.crm_prd_info;
			PRINT '>> Inserting Data Into: silver.crm_prd_info';
			INSERT INTO Silver.crm_prd_info (
				prd_id,
				cat_id,
				prd_key,
				prd_nm,
				prd_cost,
				prd_line,
				prd_start_dt,
				prd_end_dt
			)
			SELECT
				prd_id,
				REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id, -- Extract category ID
				SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key,        -- Extract product key
				prd_nm,
				ISNULL(prd_cost, 0) AS prd_cost,
				CASE 
					WHEN UPPER(TRIM(prd_line)) = 'M' THEN 'Mountain'
					WHEN UPPER(TRIM(prd_line)) = 'R' THEN 'Road'
					WHEN UPPER(TRIM(prd_line)) = 'S' THEN 'Other Sales'
					WHEN UPPER(TRIM(prd_line)) = 'T' THEN 'Touring'
					ELSE 'n/a'
				END AS prd_line, 
				CAST(prd_start_dt AS DATE) AS prd_start_dt,
				CAST(
					LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) - 1 
					AS DATE
				) AS prd_end_dt -- Calculate end date as one day before the next start date
			FROM bronze.crm_prd_info;
  

			-- Loading crm_sales_details
			PRINT '>> Truncating Table: silver.crm_sales_details';
			TRUNCATE TABLE silver.crm_sales_details;
			PRINT '>> Inserting Data Into: silver.crm_sales_details';
			INSERT INTO silver.crm_sales_details (
				sls_ord_num,
				sls_prd_key,
				sls_cust_id,
				sls_order_dt,
				sls_ship_dt,
				sls_due_dt,
				sls_sales,
				sls_quantity,
				sls_price
			)
			SELECT 
				sls_ord_num,
				sls_prd_key,
				sls_cust_id,
				CASE 
					WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
					ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
				END AS sls_order_dt,
				CASE 
					WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
					ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
				END AS sls_ship_dt,
				CASE 
					WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
					ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
				END AS sls_due_dt,
				CASE 
					WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price) 
						THEN sls_quantity * ABS(sls_price)
					ELSE sls_sales
				END AS sls_sales, -- Recalculate sales if original value is missing or incorrect
				sls_quantity,
				CASE 
					WHEN sls_price IS NULL OR sls_price <= 0
						THEN CAST(sls_sales AS DECIMAL) / NULLIF(CAST(sls_quantity AS INT), 0)
					ELSE sls_price  -- Derive price if original value is invalid
				END AS sls_price
			FROM bronze.crm_sales_details;


PRINT '---------------------------------';
PRINT 'Loading ERP Tables';
PRINT '---------------------------------';

		-- Loading erp_cust_az12
     
			TRUNCATE TABLE silver.erp_cust_az12;
			PRINT '>> Inserting Data Into: silver.erp_cust_az12';
			INSERT INTO silver.erp_cust_az12 (
				cid,
				bdate,
				gen
			)
			SELECT
				CASE
					WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid)) -- Remove 'NAS' prefix if present
					ELSE cid
				END AS cid, 
				CASE
					WHEN bdate > GETDATE() THEN NULL
					ELSE bdate
				END AS bdate, 
				CASE
					WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
					WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
					ELSE 'n/a'
				END AS gen -- Normalize gender values 
			FROM bronze.erp_cust_az12;
	-- Loading erp_loc_a101
			PRINT '>> Truncating Table: silver.erp_loc_a101';
			TRUNCATE TABLE silver.erp_loc_a101;
			PRINT '>> Inserting Data Into: silver.erp_loc_a101';
			INSERT INTO silver.erp_loc_a101 (
				cid,
				cntry
			)
			SELECT
				REPLACE(cid, '-', '') AS cid, 
				CASE
					WHEN TRIM(cntry) = 'DE' THEN 'Germany'
					WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
					WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
					ELSE TRIM(cntry)
				END AS cntry -- Normalize and Handle missing or blank country codes
			FROM bronze.erp_loc_a101;

	-- Loading erp_px_cat_g1v2
		TRUNCATE TABLE Silver.erp_px_cat_g1v2;
		INSERT INTO Silver.erp_px_cat_g1v2(
		id,
		cat,
		subcat,
		maintenance)

		SELECT 
		id,
		cat,
		subcat,
		maintenance
		FROM bronze.erp_px_cat_g1v2

		select * from Silver.erp_px_cat_g1v2
PRINT '##################################';
PRINT 'Loading The Silver Layer IS Completed ';
PRINT '##################################';

END
GO

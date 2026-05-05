/*

Stored Procedure (Bronze Layer Load)

This procedure loads data into the bronze layer tables from CSV files.

Truncates existing data in each table
Uses BULK INSERT to load data from CRM and ERP source files
Skips header rows and uses comma-separated format
Includes error handling with TRY...CATCH

Purpose: refresh raw data in bronze tables for further processing.
*/

CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN
	
	BEGIN TRY
	
PRINT '============================';
PRINT 'Loading the Bronze Layer';
PRINT '============================';

	TRUNCATE TABLE bronze.crm_cust_info;
	BULK INSERT bronze.crm_cust_info
	FROM 'C:\dwh_projects\datasets\source_crm\cust_info.csv'

	WITH (
		FIRSTROW = 2,
		FIELDTERMINATOR = ',',
		TABLOCK
	);

	TRUNCATE TABLE bronze.crm_prd_info;
	BULK INSERT bronze.crm_prd_info
	FROM 'C:\dwh_projects\datasets\source_crm\prd_info.csv'

	WITH (
		FIRSTROW = 2,
		FIELDTERMINATOR = ',',
		TABLOCK
	);

	TRUNCATE TABLE bronze.crm_sales_details;
	BULK INSERT bronze.crm_sales_details
	FROM 'C:\dwh_projects\datasets\source_crm\sales_details.csv'

	WITH (
		FIRSTROW = 2,
		FIELDTERMINATOR = ',',
		TABLOCK
	);

	TRUNCATE TABLE bronze.erp_cust_az12;
	BULK INSERT bronze.erp_cust_az12
	FROM 'C:\dwh_projects\datasets\source_erp\cust_az12.csv'

	WITH (
		FIRSTROW = 2,
		FIELDTERMINATOR = ',',
		TABLOCK
	);

	TRUNCATE TABLE bronze.erp_loc_a101;
	BULK INSERT bronze.erp_loc_a101
	FROM 'C:\dwh_projects\datasets\source_erp\loc_a101.csv'

	WITH (
		FIRSTROW = 2,
		FIELDTERMINATOR = ',',
		TABLOCK
	);

	TRUNCATE TABLE bronze.erp_px_cat_g1v2;
	BULK INSERT bronze.erp_px_cat_g1v2
	FROM 'C:\dwh_projects\datasets\source_erp\px_cat_g1v2.csv'

	WITH (
		FIRSTROW = 2,
		FIELDTERMINATOR = ',',
		TABLOCK
	);
	END TRY 
	BEGIN CATCH
		PRINT ' ================================';
		PRINT ' ERROR OCCURED DURING LOADING THE BRONZE LAYER';
		PRINT 'Error Message' + ERROR_MESSAGE();
		PRINT 'Error Message' + CAST(ERROR_NUMBER() AS NVARCHAR);

		PRINT ' ================================';
	END CATCH
	
END

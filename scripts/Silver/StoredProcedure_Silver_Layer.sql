/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load) process to 
    populate the 'silver' schema tables from the 'bronze' schema.
	Actions Performed:
		- Truncates Silver tables.
		- Inserts transformed and cleansed data from Bronze into Silver tables.
*/

create or alter procedure silver.load_silver as
begin
	declare @start_time datetime,@end_time datetime,@load_start_time datetime,@load_end_time datetime;
	begin try
		set @load_start_time = getdate();
		print '---------------------------------------------------'
		print 'Starting to load silver layer'
		print '---------------------------------------------------'

		PRINT 'Loading CRM Tables'


			print 'Truncating and Inserting data : silver.crm_cust_info'
			set @start_time = getdate();
			TRUNCATE TABLE silver.crm_cust_info;
			INSERT INTO silver.crm_cust_info (
				cst_id,
				cst_key,
				cst_firstname,
				cst_lastname,
				cst_marital_status,
				cst_gndr,
				cst_create_date)

			SELECT 
			cst_id,
			cst_key,
			TRIM(cst_firstname) as cst_firstname, -- data cleansing : removing spaces
			TRIM(cst_lastname) as cst_lastname, -- data cleansing : removing spaces
			CASE WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
				 WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
				 ELSE 'n/a' -- Handling missing data 
			END cst_marital_status, -- Data Normaliztion : Readable Fromat
			CASE WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
				 WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
				 ELSE 'n/a' -- Handling missing data 
			END as cst_gndr, -- Data Normaliztion : Readable Fromat
			cst_create_date
			FROM (
			-- Data Cleansing : Removing the nulls n duplicate from primary key column
			SELECT *,ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flg_latest
			FROM bronze.crm_cust_info
			where cst_id is not null
			) a WHERE flg_latest = 1;
			set @end_time = getdate();

			print 'silver.crm_cust_info table load completed in ' + cast(datediff(second,@start_time,@end_time) as varchar) + 'seconds';

			print 'Truncating and Inserting data : silver.crm_prd_info'
			set @start_time = getdate();

			truncate table silver.crm_prd_info;
			insert into silver.crm_prd_info (
				prd_id,
				cat_id,
				prd_key,
				prd_nm,
				prd_cost,
				prd_line,
				prd_start_dt,
				prd_end_dt
			)
			select prd_id,
			replace(substring(prd_key,1,5),'-','_') as cat_id, -- Derived Column : Category ID
			substring(prd_key,7,len(prd_key)) as prd_key, -- Derived Column : Category ID
			prd_nm,
			isnull(prd_cost,0) as prd_cost,
			case  upper(trim(prd_line)) 
				 When  'M' then 'Mountain'
				 when  'R' then 'Road'
				 when  'S' then 'Other Sales'
				 when  'T' then 'Touring'
				 else 'n/a'
			end as prd_line, -- Descriptive 
			cast(prd_start_dt as date) as prd_start_dt,
			-- calculate end_dt as 1 day before the nxt strt date
			cast(lead(prd_start_dt) over ( partition by prd_key order by prd_start_dt) -1 as date) as prd_end_dt
			from bronze.crm_prd_info;

			set @end_time = getdate();
			print 'silver.crm_prd_info table load completed in ' + cast(datediff(second,@start_time,@end_time) as varchar) + 'seconds';


			print 'Truncating and Inserting data : silver.crm_sales_details'
			set @start_time = getdate();

			truncate table silver.crm_sales_details;
			insert into silver.crm_sales_details (
			sls_ord_num ,
			sls_prd_key ,
			sls_cust_id ,
			sls_order_dt ,
			sls_ship_dt ,
			sls_due_dt ,
			sls_sales ,
			sls_quantity ,
			sls_price 
			)
			SELECT sls_ord_num,
				  sls_prd_key,
				  sls_cust_id,
				  case when sls_order_dt = 0 or len(sls_order_dt) != 8 then null
					   else cast(cast(sls_order_dt as varchar) as date)
				  end as sls_order_dt,
				  case when sls_ship_dt = 0 or len(sls_ship_dt) != 8 then null
					   else cast(cast(sls_ship_dt as varchar) as date)
				  end as sls_ship_dt,
				  case when sls_due_dt = 0 or len(sls_due_dt) != 8 then null
					   else cast(cast(sls_due_dt as varchar) as date)
				  end as sls_due_dt,
				  case when sls_sales is null or sls_sales <= 0 or sls_sales != sls_quantity * abs(sls_price)
					   then sls_quantity * abs(sls_price)
					   else sls_sales
				  end as sls_sales,
				  sls_quantity,
				  case when sls_price is null or sls_price  <= 0
					   then sls_sales / nullif(sls_quantity,0)
					   else sls_price
				  end as sls_price
			  FROM bronze.crm_sales_details;

			  set @end_time = getdate();
			  print 'silver.crm_sales_details table load completed in ' + cast(datediff(second,@start_time,@end_time) as varchar) + 'seconds';


			PRINT 'Loading ERP Tables'

			print 'Truncating and Inserting data : silver.erp_cust_az12'
			set @start_time = getdate();

			truncate table silver.erp_cust_az12;
			insert into silver.erp_cust_az12 (cid,bdate,gen)
			select 
			case when upper(cid) like 'NAS%' then substring(cid,4,len(cid)) else cid end as cid,
			case when bdate > getdate() then null else bdate end as bdate,
			case
				when upper(TRIM(gen)) in ('M','MALE') then 'Male'
				when upper(TRIM(gen)) in ('F','FEMALE') then 'Female'
				when upper(TRIM(gen)) is NULL or upper(TRIM(gen)) = ''then 'n/a'
				else TRIM(gen)
			end AS gen
			from bronze.erp_cust_az12;
			set @end_time = getdate();
			print 'silver.erp_cust_az12 table load completed in ' + cast(datediff(second,@start_time,@end_time) as varchar) + 'seconds';


			print 'Truncating and Inserting data : silver.erp_loc_a101'
			set @start_time = getdate();
			truncate table silver.erp_loc_a101;
			insert into silver.erp_loc_a101 ( cid,cntry)
			select 
			replace(cid,'-','') as cid,
			case 
				when upper(trim(cntry)) = 'DE' then 'Germany'
				when upper(trim(cntry)) in ('USA','US') then 'United States'
				when upper(trim(cntry)) = '' or upper(trim(cntry)) is null then 'n/a'
				else trim(cntry)
				end as cntry
			from bronze.erp_loc_a101;

			set @end_time = getdate();
			print 'silver.erp_loc_a101 table load completed in ' + cast(datediff(second,@start_time,@end_time) as varchar) + 'seconds';


			print 'Truncating and Inserting data : silver.erp_px_cat_g1v2'
			set @start_time = getdate();

			truncate table silver.erp_px_cat_g1v2;
			insert into silver.erp_px_cat_g1v2 (id,cat,subcat,maintenance)
			select id,cat,subcat,maintenance from bronze.erp_px_cat_g1v2;

			set @end_time = getdate();
			print 'silver.erp_px_cat_g1v2 table load completed in ' + cast(datediff(second,@start_time,@end_time) as varchar) + 'seconds';

		set @load_end_time = getdate()

		print '---------------------------------------------------'
		print 'Silver layer load Completed in ' + cast(datediff(second,@load_start_time,@load_end_time) as varchar) + 'seconds';
		print '---------------------------------------------------'
	end try

	begin catch
		print '--------------------------------------------------------'
		PRINT 'ERROR OCCURED WHILE LOADING BRONZE LAYER'
			PRINT 'ERROR MESSAGE :' + ERROR_MESSAGE();
			PRINT 'ERROR MESSAGE :' + CAST(ERROR_NUMBER() AS NVARCHAR);
			PRINT 'ERROR MESSAGE :' + CAST(ERROR_STATE() AS NVARCHAR);
		print '--------------------------------------------------------'
	end catch
end

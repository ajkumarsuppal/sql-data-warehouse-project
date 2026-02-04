--detect and identify quality issue in bronze before transformations for silver.
-- I.QUALITY CHECK
--1: Check for unwanted spaces in string values
--Expectation: No results
--sls_ord_num is FINE
--sls_prd_key IS FINE
-----------------------------------------
select * from bronze.crm_sales_details where sls_ord_num != trim(sls_ord_num);
select * from bronze.crm_sales_details where sls_prd_key != trim(sls_prd_key);
-------------------------------
--2. check if sls_prd_key and sls_cust_id are mapping correctly
select * from bronze.crm_sales_details where sls_prd_key not in (select prd_key from silver.crm_prd_info);
select * from bronze.crm_sales_details where sls_cust_id not in (select cst_id  from silver.crm_cust_info);
-------------------------------
--3. sls_order_dt,sls_ship_dt,sls_due_dt are in int. need to convert these to date
--keep in mind that -ve or zeros cant be cast to date
select * from bronze.crm_sales_details where sls_order_dt <= 0;
--so we turn these values to null so it cant be casted
select nullif(sls_order_dt,0) as sls_order_dt
from bronze.crm_sales_details 
where sls_order_dt <= 0 or len(sls_order_dt)!= 8;
--YYYYMMDD
--so length of each record is 8
--check for outliers by validating boundaries of date range
--cant cast int to date in ssms. need to convert to varchar first and then to date
select
	sls_ord_num,
	sls_prd_key,
	sls_cust_id,
	case
		when sls_order_dt = 0 or len(sls_order_dt) != 8 then NULL
		else cast(cast(sls_order_dt as varchar) as date)
	end as sls_order_dt,
	case
		when sls_ship_dt = 0 or len(sls_ship_dt) != 8 then NULL
		else cast(cast(sls_ship_dt as varchar) as date)
	end as sls_ship_dt,
	case
		when sls_due_dt = 0 or len(sls_due_dt) != 8 then NULL
		else cast(cast(sls_due_dt as varchar) as date)
	end as sls_due_dt,
	sls_sales,
	sls_quantity,
	sls_price
from bronze.crm_sales_details;
--sls_order_dt should be smaller than sls_ship_dt or sls_due_dt
select
	sls_ord_num,
	sls_prd_key,
	sls_cust_id,
	case
		when sls_order_dt = 0 or len(sls_order_dt) != 8 then NULL
		else cast(cast(sls_order_dt as varchar) as date)
	end as sls_order_dt,
	case
		when sls_ship_dt = 0 or len(sls_ship_dt) != 8 then NULL
		else cast(cast(sls_ship_dt as varchar) as date)
	end as sls_ship_dt,
	case
		when sls_due_dt = 0 or len(sls_due_dt) != 8 then NULL
		else cast(cast(sls_due_dt as varchar) as date)
	end as sls_due_dt,
	sls_sales,
	sls_quantity,
	sls_price
from bronze.crm_sales_details
where sls_order_dt > sls_ship_dt or sls_order_dt > sls_due_dt;
-------------------------------

--4. check data consistency: between sales, quantity and price
-- business rule: sales = quantity * price
-- values with -ve, 0, NULL not allowed
select 
	sls_sales,
	sls_quantity,
	sls_price
from bronze.crm_sales_details
where sls_sales != sls_quantity * sls_price
or sls_sales is null or sls_quantity is null or sls_price is null
or sls_sales <=0 or sls_quantity <=0 or sls_price <=0
order by sls_sales,	sls_quantity,sls_price;
--quality of sales and price is bad
--1.solution: data issues will be fixed in source system
--2.data issues need to be fixed in dwh

--so we standardize rules
--a. if SALES is -ve, 0 or null, we derive it using quantity and price
--b. if PRICE is 0 or null, we derive it using quantity and sales. if it is -ve, convert it to +ve

select 
	sls_sales as old_sales,
	sls_price as old_price,
	sls_quantity,
	case
		when sls_sales is null or sls_sales <=0 or sls_sales != sls_quantity * abs(sls_price) then sls_quantity * abs(sls_price)
		else sls_sales
	end as sls_sales,
	case
		when sls_price is null or sls_price <=0 then sls_sales/nullif(sls_quantity,0)
		else sls_price
	end as sls_price
from bronze.crm_sales_details
where sls_sales != sls_quantity * sls_price
or sls_sales is null or sls_quantity is null or sls_price is null
or sls_sales <=0 or sls_quantity <=0 or sls_price <=0
order by sls_sales,	sls_quantity,sls_price;

--add this in transformation logic buildup-
select
	sls_ord_num,
	sls_prd_key,
	sls_cust_id,
	case
		when sls_order_dt = 0 or len(sls_order_dt) != 8 then NULL
		else cast(cast(sls_order_dt as varchar) as date)
	end as sls_order_dt,
	case
		when sls_ship_dt = 0 or len(sls_ship_dt) != 8 then NULL
		else cast(cast(sls_ship_dt as varchar) as date)
	end as sls_ship_dt,
	case
		when sls_due_dt = 0 or len(sls_due_dt) != 8 then NULL
		else cast(cast(sls_due_dt as varchar) as date)
	end as sls_due_dt,
	case
		when sls_sales is null or sls_sales <=0 or sls_sales != sls_quantity * abs(sls_price) then sls_quantity * abs(sls_price)
		else sls_sales
	end as sls_sales,
	sls_quantity,
	case
		when sls_price is null or sls_price <=0 then sls_sales/nullif(sls_quantity,0)
		else sls_price
	end as sls_price
from bronze.crm_sales_details;
-------------------------------
--check datatype in silver ddl for table: crm_sales_details

--now we can insert the cleaned data in silver table

INSERT INTO silver.crm_sales_details (
	sls_ord_num,
	sls_prd_key,
	sls_cust_id,
	sls_order_dt,
	sls_ship_dt,
	sls_due_dt,
	sls_sales,
	sls_quantity,
	sls_price)

select
	sls_ord_num,
	sls_prd_key,
	sls_cust_id,
	case
		when sls_order_dt = 0 or len(sls_order_dt) != 8 then NULL
		else cast(cast(sls_order_dt as varchar) as date)
	end as sls_order_dt,
	case
		when sls_ship_dt = 0 or len(sls_ship_dt) != 8 then NULL
		else cast(cast(sls_ship_dt as varchar) as date)
	end as sls_ship_dt,
	case
		when sls_due_dt = 0 or len(sls_due_dt) != 8 then NULL
		else cast(cast(sls_due_dt as varchar) as date)
	end as sls_due_dt,
	case
		when sls_sales is null or sls_sales <=0 or sls_sales != sls_quantity * abs(sls_price) then sls_quantity * abs(sls_price)
		else sls_sales
	end as sls_sales,
	sls_quantity,
	case
		when sls_price is null or sls_price <=0 then sls_sales/nullif(sls_quantity,0)
		else sls_price
	end as sls_price
from bronze.crm_sales_details;
--===========================================
--check if data loaded in silver table
select *
from silver.crm_sales_details;

--quality check of silver table
--1. check for invalid date orders
--expectations: no result
--crm_prd_info
select * from silver.crm_sales_details
where sls_order_dt > sls_ship_dt or sls_order_dt > sls_due_dt;

--2: Check for check data consistency: between sales, quantity and price
--Expectation: No results

select 
	sls_sales as old_sales,
	sls_price as old_price,
	sls_quantity,
	sls_sales,
	sls_price
from silver.crm_sales_details
where sls_sales != sls_quantity * sls_price
or sls_sales is null or sls_quantity is null or sls_price is null
or sls_sales <=0 or sls_quantity <=0 or sls_price <=0
order by sls_sales,	sls_quantity,sls_price;
-------------------------------

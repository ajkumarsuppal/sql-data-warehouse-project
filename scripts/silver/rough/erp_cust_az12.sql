--detect and identify quality issue in bronze before transformations for silver.
select * from bronze.erp_cust_az12;
select * from silver.crm_cust_info where cst_key='AW00022042';
-- I.QUALITY CHECK
-------------------------------
--1. check cid can be mapped to cst_key in crm_cust_info
--we could see that cid is prefixed with NAS and newer values look like cst_key
--TRNSFORMATION: build up part1
select
	case
		when cid like 'NAS%' then substring(cid,4,len(cid))
		else cid
	end as cid
from bronze.erp_cust_az12;
-------------------------------
--2: Check for unwanted spaces in string values
--Expectation: No results
--cid is FINE
--gen IS FINE
-----------------------------------------
select * from bronze.erp_cust_az12 where cid != trim(cid);
select * from bronze.erp_cust_az12 where gen != trim(gen);
-------------------------------
--3: identify out of range dates
--check if cust age >=100
select * from bronze.erp_cust_az12 where bdate < '1926-01-01' or bdate > GETDATE(); 
--TRNSFORMATION: build up part2
select
	case
		when cid like 'NAS%' then substring(cid,4,len(cid))
		else cid
	end as cid,
	case
		when bdate > GETDATE() then NULL
		else bdate
	end as bdate
from bronze.erp_cust_az12;
-------------------------------
--4.check consistency of value in low cardinality columns
--data standardization and consistency 
select distinct gen from bronze.erp_cust_az12;
--values: NULL, F, blank, Male, Female, M
select * from bronze.erp_cust_az12 where gen = '';
select
	distinct 
	case 
		when upper(trim(gen)) in ('F','FEMALE') then 'Female'
		when upper(trim(gen)) in ('M','MALE') then 'Male'
		else 'n/a'
	end as gen
from bronze.erp_cust_az12;

--TRNSFORMATION: build up part3
select
	case
		when cid like 'NAS%' then substring(cid,4,len(cid))
		else cid
	end as cid,
	case
		when bdate > GETDATE() then NULL
		else bdate
	end as bdate,
	case 
		when upper(trim(gen)) in ('F','FEMALE') then 'Female'
		when upper(trim(gen)) in ('M','MALE') then 'Male'
		else 'n/a'
	end as gen
from bronze.erp_cust_az12;
-------------------------------
--now we can insert the cleaned data in silver table
INSERT INTO silver.erp_cust_az12 (
	cid,
	bdate,
	gen
)
select
	case
		when cid like 'NAS%' then substring(cid,4,len(cid))
		else cid
	end as cid,
	case
		when bdate > GETDATE() then NULL
		else bdate
	end as bdate,
	case 
		when upper(trim(gen)) in ('F','FEMALE') then 'Female'
		when upper(trim(gen)) in ('M','MALE') then 'Male'
		else 'n/a'
	end as gen
from bronze.erp_cust_az12;
---------
--quality check for silver table
--1. check cid can be mapped to cst_key in crm_cust_info
--we could see that cid is prefixed with NAS and newer values look like cst_key
--TRNSFORMATION: build up part1
select
	cid
from silver.erp_cust_az12;
-------------------------------
--2: Check for unwanted spaces in string values
--Expectation: No results
--cid is FINE
--gen IS FINE
-----------------------------------------
select * from silver.erp_cust_az12 where cid != trim(cid);
select * from silver.erp_cust_az12 where gen != trim(gen);
-------------------------------
--3: identify out of range dates
--check if cust age >=100
select * from silver.erp_cust_az12 where bdate > GETDATE(); 
-------------------------------
--4.check consistency of value in low cardinality columns
--data standardization and consistency 
select distinct gen from silver.erp_cust_az12;

--===========================================
--check if data loaded in silver table
select * from silver.crm_sales_details;
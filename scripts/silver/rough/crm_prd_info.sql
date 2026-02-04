--detect and identify quality issue in bronze before transformations for silver.
-- I.QUALITY CHECK
-----------------------------------------
--1. check primary key - must be unique and not null. should have no duplicates
--check for nulls or duplicates in primary key
--expectations: no result
--crm_prd_info
select prd_id, count(*)
from bronze.crm_prd_info 
group by prd_id
having count(*) > 1 or prd_id is null
order by prd_id ;
--All good
------------
select * from bronze.crm_prd_info ;
-------------------------------
--prd_key has a lot of information
--first 5 characters need to map with id of erp_px_cat_g1v2 (instead of -, erp table has _; so need to replace - with _) AS cat_id
--6th to last characters need to map with sls_prd_key of crm_sales_details
--2.SO WE NEED TO SPLIT prd_key into 2 informations: DERIVE 2 NEW COLUMNS
--2.1
select
	prd_id,
	prd_key,
	REPLACE(SUBSTRING(prd_key,1,5),'-','_') as cat_id,
	prd_nm,
	prd_cost,
	prd_line,
	prd_start_dt,
	prd_end_dt
from bronze.crm_prd_info;

SELECT DISTINCT id FROM bronze.erp_px_cat_g1v2;

-- CHECK: filter out unmatched data after applying transformation

select
	prd_id,
	prd_key,
	REPLACE(SUBSTRING(prd_key,1,5),'-','_') as cat_id,
	prd_nm,
	prd_cost,
	prd_line,
	prd_start_dt,
	prd_end_dt
from bronze.crm_prd_info
where REPLACE(SUBSTRING(prd_key,1,5),'-','_') not in (
SELECT DISTINCT id FROM bronze.erp_px_cat_g1v2);
--we found CO_PE is not present in erp_px_cat_g1v2 which is okay

--2.2
--prd_key for sls_prd_key of crm_sales_details

select
	prd_id,
	prd_key,
	REPLACE(SUBSTRING(trim(prd_key),1,5),'-','_') as cat_id,
	SUBSTRING(trim(prd_key),7,len(trim(prd_key))) as prd_key,
	prd_nm,
	prd_cost,
	prd_line,
	prd_start_dt,
	prd_end_dt
from bronze.crm_prd_info;

select sls_prd_key from bronze.crm_sales_details;

--CHECK: filter out unmatched data after applying transformation

select
	prd_id,
	prd_key,
	REPLACE(SUBSTRING(trim(prd_key),1,5),'-','_') as cat_id,
	SUBSTRING(trim(prd_key),7,len(trim(prd_key))) as prd_key,
	prd_nm,
	prd_cost,
	prd_line,
	prd_start_dt,
	prd_end_dt
from bronze.crm_prd_info 
where SUBSTRING(trim(prd_key),7,len(trim(prd_key))) not in (
select trim(sls_prd_key) from bronze.crm_sales_details);
--we could see a lot of products not having any orders
-------------------------------

--3: Check for unwanted spaces in string values
--Expectation: No results
--prd_nm IS FINE

select prd_nm
from bronze.crm_prd_info
where prd_nm != trim(prd_nm);
-------------------------------

--4. check for NULLs or NEGATIVE numbers
--Expectation: No results
select prd_id,prd_cost
from bronze.crm_prd_info
where prd_cost is NULL or prd_cost < 0;
--need to replace null with 0 using ISNULL
select
	prd_id,
	prd_key,
	REPLACE(SUBSTRING(trim(prd_key),1,5),'-','_') as cat_id,
	SUBSTRING(trim(prd_key),7,len(trim(prd_key))) as prd_key,
	prd_nm,
	ISNULL(prd_cost,0) AS prd_cost,
	prd_line,
	prd_start_dt,
	prd_end_dt
from bronze.crm_prd_info;
-------------------------------
--5. check consistency of value in low cardinality columns
--data standardization and consistency
--prd_line
select distinct prd_line
from bronze.crm_prd_info;
--in our dwh, we can make a rule, instead of going with abbreviations, we aim to store clear and meaningful values
--so for prd_line, NULL=n/a, M=Mountain, R=Road , S=Other Sales , T= Touring
select
	prd_id,
	--prd_key,
	REPLACE(SUBSTRING(trim(prd_key),1,5),'-','_') as cat_id,
	SUBSTRING(trim(prd_key),7,len(trim(prd_key))) as prd_key,
	prd_nm,
	ISNULL(prd_cost,0) AS prd_cost,
	case UPPER(TRIM(prd_line))
		when 'M' then 'Mountain'
		when 'R' then 'Road'
		when 'S' then 'Other Sales'
		when 'T' then 'Touring'
		else 'n/a'
	end as prd_line,
	prd_start_dt,
	prd_end_dt
from bronze.crm_prd_info;

--6.check for invalid date orders
--6.1 end date must not be earlier than start date
select * from
bronze.crm_prd_info
where prd_end_dt<prd_start_dt;
--one approach is we could switch end and start date but it doesn't make sense as for a prd_key, start_dt cant be gt than end_dt
--second approach and more stable is to use next start_dt - 1 of a prd as the current records' end_dt
select *
from bronze.crm_prd_info
where prd_key in ('AC-HE-HL-U509','AC-HE-HL-U509-R');

select 
	prd_id,
	prd_key,
	REPLACE(SUBSTRING(trim(prd_key),1,5),'-','_') as cat_id,
	SUBSTRING(trim(prd_key),7,len(trim(prd_key))) as prd_key,
	prd_nm,
	ISNULL(prd_cost,0) AS prd_cost,
	case UPPER(TRIM(prd_line))
		when 'M' then 'Mountain'
		when 'R' then 'Road'
		when 'S' then 'Other Sales'
		when 'T' then 'Touring'
		else 'n/a'
	end as prd_line,
	cast(prd_start_dt as date) as prd_start_dt,
	cast(lead(prd_start_dt) over (partition by SUBSTRING(trim(prd_key),7,len(trim(prd_key))) order by prd_start_dt) - 1 as date) as prd_endt_dt_test
--	,prd_end_dt --we don't need prd_end_dt as we have derived it using lead on start_dt
from bronze.crm_prd_info
order by prd_id,3,4;

--so now we need to do few modifications in the ddl as well as we have added cat_id, changed prd_start_dt from DATETIME to DATE
IF OBJECT_ID('silver.crm_prd_info', 'U') IS NOT NULL
    DROP TABLE silver.crm_prd_info;
GO

CREATE TABLE silver.crm_prd_info (
    prd_id          INT,
    cat_id          NVARCHAR(50),
    prd_key         NVARCHAR(50),
    prd_nm          NVARCHAR(50),
    prd_cost        INT,
    prd_line        NVARCHAR(50),
    prd_start_dt    DATE,
    prd_end_dt      DATE,
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);

--now we can insert the cleaned data in silver table

INSERT INTO silver.crm_prd_info (
	prd_id,
	cat_id,
	prd_key,
	prd_nm,
	prd_cost,
	prd_line,
	prd_start_dt,
	prd_end_dt)

select 
	prd_id,
	REPLACE(SUBSTRING(trim(prd_key),1,5),'-','_') as cat_id,
	SUBSTRING(trim(prd_key),7,len(trim(prd_key))) as prd_key,
	prd_nm,
	ISNULL(prd_cost,0) AS prd_cost,
	case UPPER(TRIM(prd_line))
		when 'M' then 'Mountain'
		when 'R' then 'Road'
		when 'S' then 'Other Sales'
		when 'T' then 'Touring'
		else 'n/a'
	end as prd_line,
	cast(prd_start_dt as date) as prd_start_dt,
	cast(lead(prd_start_dt) over (partition by SUBSTRING(trim(prd_key),7,len(trim(prd_key))) order by prd_start_dt) - 1 as date) as prd_endt_dt_test
--	,prd_end_dt --we don't need prd_end_dt as we have derived it using lead on start_dt
from bronze.crm_prd_info
order by prd_id,3,4;

--check if data loaded in silver table
select *
from silver.crm_prd_info

--quality check of silver table
--1. check primary key - must be unique and not null. should have no duplicates
--expectations: no result
--crm_prd_info
select prd_id, count(*)
from silver.crm_prd_info 
group by prd_id
having count(*) > 1 or prd_id is null
order by prd_id ;

--2: Check for unwanted spaces in string values
--Expectation: No results

select prd_nm
from silver.crm_prd_info
where prd_nm != trim(prd_nm);
-------------------------------

--3. check for NULLs or NEGATIVE numbers
--Expectation: No results
select prd_id,prd_cost
from silver.crm_prd_info
where prd_cost is NULL or prd_cost < 0;

--4. check consistency of value in low cardinality columns
--data standardization and consistency
--prd_line
select distinct prd_line
from silver.crm_prd_info;

--5.check for invalid date orders
select * from
silver.crm_prd_info
where prd_end_dt<prd_start_dt;
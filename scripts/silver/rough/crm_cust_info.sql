--detect and identify quality issue in bronze before transformations for silver.
-- I.QUALITY CHECK
-----------------------------------------
--1. check primary key - must be unique and not null. should have no duplicates
--check for nulls or duplicates in primary key
--expectations: no result
--crm_cust_info
select cst_id, count(*)
from bronze.crm_cust_info 
group by cst_id
having count(*) > 1 or cst_id is null
order by cst_id ;
--we got cst_ids which have count > 1 as well as NULL values
---------------------------------------
--so we will write a query that will do data transformation and data cleansing
--start with querying for id for which we saw an issue
--we could see for same PK, we have multiple entries and the last updated entry has the correct info. so we use window function to fetch the latest record
select * from 
(
	select cci.*, ROW_NUMBER() over (partition by cci.cst_id order by cci.cst_create_date desc) as flag_last
	from bronze.crm_cust_info cci
	where cst_id in (29433,29449,29466,29473,29483) or cst_id is null
	)a
	where a.flag_last=1;

--for all data, we remove where clause. we see that rows reduced from 18493 to 18484
--FETCH UNIQUE RECORDS
--TRANSFORMATION QUERY BUILDUP
select * from 
(
	select cci.*, ROW_NUMBER() over (partition by cci.cst_id order by cci.cst_create_date desc) as flag_last
	from bronze.crm_cust_info cci
	where cst_id is not null
)a
where a.flag_last=1;
--2. as a lot of columns hold string values
--------------------------
	--2.1: Check for unwanted spaces in string values
	--Expectation: No results
--cst_key IS FINE
select cst_key
from bronze.crm_cust_info
where cst_key != trim(cst_key);

--cst_firstname HAS GOT UNWANTED SPACES
select cst_firstname
from bronze.crm_cust_info
where cst_firstname != trim(cst_firstname);

--cst_lastname HAS GOT UNWANTED SPACES
select cst_lastname
from bronze.crm_cust_info
where cst_lastname != trim(cst_lastname);

--cst_marital_status IS FINE
select cst_marital_status
from bronze.crm_cust_info
where cst_marital_status != trim(cst_marital_status);

--CST_GNDR IS FINE
select cst_gndr
from bronze.crm_cust_info
where cst_gndr != trim(cst_gndr);
----------------------
--TRANSFORMATION QUERY BUILDUP. part-2
select 
	cst_id,
	cst_key,
	trim(cst_firstname) as cst_firstname,
	trim(cst_lastname) as cst_lastname,
	cst_marital_status,
	cst_gndr,
	cst_create_date
from 
(
	select cci.*, ROW_NUMBER() over (partition by cci.cst_id order by cci.cst_create_date desc) as flag_last
	from bronze.crm_cust_info cci
	where cst_id is not null
)a
where a.flag_last=1;

----------------------------
--3. check consistency of value in low cardinality columns
--data standardization and consistency 
--cst_gndr
select distinct cst_gndr
from bronze.crm_cust_info;

--cst_marital_status
select distinct cst_marital_status
from bronze.crm_cust_info;
----------------
--in our dwh, we can make a rule, instead of going with abbreviations, we aim to store clear and meaningful values
--so for cst_gndr: NULL=n/a, F=Female, M=Male
--for cst_marital_status: NULL-n/a, M=Married, S=Single

--TRANSFORMATION QUERY BUILDUP. part-3
select 
	cst_id,
	cst_key,
	trim(cst_firstname) as cst_firstname,
	trim(cst_lastname) as cst_lastname,
	case
		when upper(trim(cst_marital_status)) = 'S' then 'Single'
		when upper(trim(cst_marital_status)) = 'M' then 'Married'
		else 'n/a'
	end as cst_marital_status,
	case
		when upper(trim(cst_gndr)) = 'M' then 'Male'
		when upper(trim(cst_gndr)) = 'F' then 'Female'
		else 'n/a'
	end as cst_gndr,
	cst_create_date
from 
(
	select cci.*, ROW_NUMBER() over (partition by cci.cst_id order by cci.cst_create_date desc) as flag_last
	from bronze.crm_cust_info cci
	where cst_id is not null
)a
where a.flag_last=1;

--for date column cst_create_date, we need to ensure it is date and not some string type

--now we can write the insert statement for silver layer.
INSERT INTO silver.crm_cust_info (
cst_id,
cst_key,
cst_firstname,
cst_lastname,
cst_marital_status,
cst_gndr,
cst_create_date)

select 
	cst_id,
	cst_key,
	trim(cst_firstname) as cst_firstname,
	trim(cst_lastname) as cst_lastname,
	case
		when upper(trim(cst_marital_status)) = 'S' then 'Single'
		when upper(trim(cst_marital_status)) = 'M' then 'Married'
		else 'n/a'
	end as cst_marital_status,
	case
		when upper(trim(cst_gndr)) = 'M' then 'Male'
		when upper(trim(cst_gndr)) = 'F' then 'Female'
		else 'n/a'
	end as cst_gndr,
	cst_create_date
from 
(
	select cci.*, ROW_NUMBER() over (partition by cci.cst_id order by cci.cst_create_date desc) as flag_last
	from bronze.crm_cust_info cci
	where cst_id is not null
)a
where a.flag_last=1;
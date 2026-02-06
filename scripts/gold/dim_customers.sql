select * from silver.crm_cust_info;
--we will now select columns we need to present in gold layer.
select
	ci.cst_id,
	ci.cst_key,
	ci.cst_firstname,
	ci.cst_lastname,
	ci.cst_marital_status,
	ci.cst_gndr,
	ci.cst_create_date
from silver.crm_cust_info ci;
-- we giving alias because we will join this table with others

--we will now jump to another customer table containing birthdaate info
select * from silver.erp_cust_az12;
--we will now select columns we need to present in gold layer.
select
	ca.cid,
	ca.bdate,
	ca.gen
from silver.erp_cust_az12 ca;

--we will join these two table with cst_key and cid
--avoid inner join as if other table doesnt have all info, i might lose customers
--always, start from master table and try to left join other tables
select
	ci.cst_id,
	ci.cst_key,
	ci.cst_firstname,
	ci.cst_lastname,
	ci.cst_marital_status,
	ci.cst_gndr,
	ci.cst_create_date,
	ca.bdate,
	ca.gen
from silver.crm_cust_info ci
left join silver.erp_cust_az12 ca on ci.cst_key = ca.cid;
--check if nulls of joined table are because cid is not having that id
select * from silver.erp_cust_az12 where cid='AW00029483';

--join erp_loc_a101 to fetch location with cid and cst_key
select * from silver.erp_loc_a101;

select
	ci.cst_id,
	ci.cst_key,
	ci.cst_firstname,
	ci.cst_lastname,
	ci.cst_marital_status,
	ci.cst_gndr,
	ci.cst_create_date,
	ca.bdate,
	ca.gen,
	la.cntry
from silver.crm_cust_info ci
left join silver.erp_cust_az12 ca on ci.cst_key = ca.cid
left join silver.erp_loc_a101 la on ci.cst_key=la.cid;
--after joining table, check if any duplicates introduced by join logic
--finding if we have duplicates in primary key
select 
	cst_id, count(*) 
from (
	select
		ci.cst_id,
		ci.cst_key,
		ci.cst_firstname,
		ci.cst_lastname,
		ci.cst_marital_status,
		ci.cst_gndr,
		ci.cst_create_date,
		ca.bdate,
		ca.gen,
		la.cntry
	from silver.crm_cust_info ci
	left join silver.erp_cust_az12 ca on ci.cst_key = ca.cid
	left join silver.erp_loc_a101 la on ci.cst_key=la.cid
)t
group by cst_id
having count(*) > 1;
--all good.

--we have integration issues. got 2 sources for gender info coming from crm and erp
select distinct
	ci.cst_gndr,
	ca.gen
from silver.crm_cust_info ci
left join silver.erp_cust_az12 ca on ci.cst_key = ca.cid
order by 1,2;
--null appearing as a result of unmatch.
--issues where cst_gndr is Male and gen is Female and vice versa
--for some cst_gndr n/a, we got values in gen and vice versa so that is useful
--we ask experts to understand which table is master for customer information.
--master source of customer data is crm.
--so for issues where cst_gndr is Male and gen is Female and vice versa, we will consider cst_gndr

--1. build business rule
select distinct
	ci.cst_gndr,
	ca.gen,
	case
		when ci.cst_gndr != 'n/a' then ci.cst_gndr --crm is master for gender info
		else coalesce(ca.gen, 'n/a') -- gen can be null for cst_key not present as cid in erp. so need to handle these
	end as new_gen
from silver.crm_cust_info ci
left join silver.erp_cust_az12 ca on ci.cst_key = ca.cid
order by 1,2;
--use this enriched information in our main query that we are building for customer information

select
	ci.cst_id,
	ci.cst_key,
	ci.cst_firstname,
	ci.cst_lastname,
	ci.cst_marital_status,
	case
		when ci.cst_gndr != 'n/a' then ci.cst_gndr --crm is master for gender info
		else coalesce(ca.gen, 'n/a') -- gen can be null for cst_key not present as cid in erp. so need to handle these
	end as new_gen,
	ci.cst_create_date,
	ca.bdate,
	la.cntry
from silver.crm_cust_info ci
left join silver.erp_cust_az12 ca on ci.cst_key = ca.cid
left join silver.erp_loc_a101 la on ci.cst_key=la.cid;

--rename columns to friendly, meaningful names

select
	ci.cst_id as customer_id,
	ci.cst_key as customer_number,
	ci.cst_firstname as first_name,
	ci.cst_lastname as last_name,
	ci.cst_marital_status as marital_status,
	case
		when ci.cst_gndr != 'n/a' then ci.cst_gndr --crm is master for gender info
		else coalesce(ca.gen, 'n/a') -- gen can be null for cst_key not present as cid in erp. so need to handle these
	end as gender,
	ci.cst_create_date as create_date,
	ca.bdate as birthdate,
	la.cntry as country
from silver.crm_cust_info ci
left join silver.erp_cust_az12 ca on ci.cst_key = ca.cid
left join silver.erp_loc_a101 la on ci.cst_key=la.cid;

--sort the columns to logical groups to improve readability

select
	ci.cst_id as customer_id,
	ci.cst_key as customer_number,
	ci.cst_firstname as first_name,
	ci.cst_lastname as last_name,
	la.cntry as country,
	ci.cst_marital_status as marital_status,
	case
		when ci.cst_gndr != 'n/a' then ci.cst_gndr --crm is master for gender info
		else coalesce(ca.gen, 'n/a') -- gen can be null for cst_key not present as cid in erp. so need to handle these
	end as gender,
	ca.bdate as birthdate,
	ci.cst_create_date as create_date
from silver.crm_cust_info ci
left join silver.erp_cust_az12 ca on ci.cst_key = ca.cid
left join silver.erp_loc_a101 la on ci.cst_key=la.cid;

--is this dimension or fact?? DIMENSION
--IF NEW DIMENSION IS CREATED, WE ALWAYS NEED A pk. 
--it can happen sometimes there is no column that can be counted as PK from source system tables. so we generate PK in dwh and is called surrogate keys
--surrogate keys-> system generated unique identifier assigned to each record in table to make records unique.
--its not business key. it has no meaning and no one in business knows about it. we only use it to connect our data models.
--this gives us more control on how to connect data model and we dont need to always depend on source system.

--DIFFERENT WAYS TO GENERATE SURROGATE KEY
--1. ddl BASED GENERATION
--2. query based using windows function (row_number)

select
	row_number() over (order by ci.cst_id) as customer_key,
	ci.cst_id as customer_id,
	ci.cst_key as customer_number,
	ci.cst_firstname as first_name,
	ci.cst_lastname as last_name,
	la.cntry as country,
	ci.cst_marital_status as marital_status,
	case
		when ci.cst_gndr != 'n/a' then ci.cst_gndr --crm is master for gender info
		else coalesce(ca.gen, 'n/a') -- gen can be null for cst_key not present as cid in erp. so need to handle these
	end as gender,
	ca.bdate as birthdate,
	ci.cst_create_date as create_date
from silver.crm_cust_info ci
left join silver.erp_cust_az12 ca on ci.cst_key = ca.cid
left join silver.erp_loc_a101 la on ci.cst_key=la.cid;

--last step: CREATE OBJECT (virtual) -> create a view

create view gold.dim_customers as
select
	row_number() over (order by ci.cst_id) as customer_key,
	ci.cst_id as customer_id,
	ci.cst_key as customer_number,
	ci.cst_firstname as first_name,
	ci.cst_lastname as last_name,
	la.cntry as country,
	ci.cst_marital_status as marital_status,
	case
		when ci.cst_gndr != 'n/a' then ci.cst_gndr --crm is master for gender info
		else coalesce(ca.gen, 'n/a') -- gen can be null for cst_key not present as cid in erp. so need to handle these
	end as gender,
	ca.bdate as birthdate,
	ci.cst_create_date as create_date
from silver.crm_cust_info ci
left join silver.erp_cust_az12 ca on ci.cst_key = ca.cid
left join silver.erp_loc_a101 la on ci.cst_key=la.cid;

-------------------------------------------------------
--quality check of gold table
select * from gold.dim_customers;

--1.
select distinct gender from gold.dim_customers;

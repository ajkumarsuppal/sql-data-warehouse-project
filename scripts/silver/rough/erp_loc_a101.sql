--detect and identify quality issue in bronze before transformations for silver.
select cid, cntry from bronze.erp_loc_a101;
-- I.QUALITY CHECK
-------------------------------
--1. 
--cid of erp_loc_a101 is mapped to cst_key of crm_cust_info. so need to format it.
select
	replace(cid,'-','') as cid
from bronze.erp_loc_a101;

--check with other table
select
	replace(cid,'-','') as cid
from bronze.erp_loc_a101
where replace(cid,'-','') not in (select cst_key from silver.crm_cust_info);
-------------------------------
--2.check consistency of value in low cardinality columns
--DATA STANDARDIZATION AND CONSISTENCY
select distinct cntry from bronze.erp_loc_a101;

select
	case
		when trim(cntry) in ('US','USA') then 'United States'
		when trim(cntry) in ('DE') then 'Germany'
		when trim(cntry) = '' or cntry is null then 'n/a'
		else cntry
	end as cntry
from bronze.erp_loc_a101;

--quality check
select distinct cntry as old_country,
	case
		when trim(cntry) in ('US','USA') then 'United States'
		when trim(cntry) in ('DE') then 'Germany'
		when trim(cntry) = '' or cntry is null then 'n/a'
		else cntry
	end as cntry
from bronze.erp_loc_a101
order by cntry;

--TRANSFORMATION logic:
select
	replace(cid,'-','') as cid,
	case
		when trim(cntry) in ('US','USA') then 'United States'
		when trim(cntry) in ('DE') then 'Germany'
		when trim(cntry) = '' or cntry is null then 'n/a'
		else trim(cntry)
	end as cntry
from bronze.erp_loc_a101;

--===========================================
--now we can insert the cleaned data in silver table
INSERT INTO silver.erp_loc_a101 (
	cid,
	cntry
)
select
	replace(cid,'-','') as cid,
	case
		when trim(cntry) in ('US','USA') then 'United States'
		when trim(cntry) in ('DE') then 'Germany'
		when trim(cntry) = '' or cntry is null then 'n/a'
		else trim(cntry)
	end as cntry
from bronze.erp_loc_a101;

---------
--quality check for silver table
--1.check consistency of value in low cardinality columns
--DATA STANDARDIZATION AND CONSISTENCY
select distinct cntry from silver.erp_loc_a101;

--===========================================
--check if data loaded in silver table
select * from silver.erp_loc_a101;
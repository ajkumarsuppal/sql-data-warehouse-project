--detect and identify quality issue in bronze before transformations for silver.
select 
	id,
	cat,
	subcat,
	maintenance
from bronze.erp_px_cat_g1v2;
-- I.QUALITY CHECK
-------------------------------
--1.
--id of this table neeeds to be mapped to prd_key(cat_id of silver table) of crm_prd_info
select * from silver.crm_prd_info;
--id is fine in erp table
-------------------------------
--2. check unwanted spaces
--id is fine
select *
from bronze.erp_px_cat_g1v2
where id !=trim(id);
--cat is fine
select *
from bronze.erp_px_cat_g1v2
where cat !=trim(cat);
--subcat is fine
select *
from bronze.erp_px_cat_g1v2
where subcat !=trim(subcat);
--maintenance is fine
select *
from bronze.erp_px_cat_g1v2
where maintenance !=trim(maintenance);
-------------------------------
--3. check consistency of value in low cardinality columns
--DATA STANDARDIZATION AND CONSISTENCY
--cat is fine
select distinct cat from bronze.erp_px_cat_g1v2;
--subcat is fine
select distinct subcat from bronze.erp_px_cat_g1v2;
--cat is fine
select distinct maintenance from bronze.erp_px_cat_g1v2;

--all is good in erp_px_cat_g1v2

--===========================================
--now we can insert the cleaned data in silver table
INSERT INTO silver.erp_px_cat_g1v2 (
	id,
	cat,
	subcat,
	maintenance
)
select 
	id,
	cat,
	subcat,
	maintenance
from bronze.erp_px_cat_g1v2;

--===========================================

--quality check for silver table
--1. check unwanted spaces
--id is fine
select *
from silver.erp_px_cat_g1v2
where id !=trim(id);
--cat is fine
select *
from silver.erp_px_cat_g1v2
where cat !=trim(cat);
--subcat is fine
select *
from silver.erp_px_cat_g1v2
where subcat !=trim(subcat);
--maintenance is fine
select *
from silver.erp_px_cat_g1v2
where maintenance !=trim(maintenance);
-------------------------------
--3. check consistency of value in low cardinality columns
--DATA STANDARDIZATION AND CONSISTENCY
--cat is fine
select distinct cat from silver.erp_px_cat_g1v2;
--subcat is fine
select distinct subcat from silver.erp_px_cat_g1v2;
--cat is fine
select distinct maintenance from silver.erp_px_cat_g1v2;

--check if data loaded in silver table
select 	* from silver.erp_px_cat_g1v2;
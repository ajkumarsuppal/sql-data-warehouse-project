--from data integration diagram, we find which tables belong to dim products.
select * from silver.crm_prd_info;
--we will now select columns we need to present in gold layer.
select
	pi.prd_id,
	pi.cat_id,
	pi.prd_key,
	pi.prd_nm,
	pi.prd_cost,
	pi.prd_line,
	pi.prd_start_dt,
	pi.prd_end_dt
from silver.crm_prd_info pi;
--this object contains historical info as well as current
--depending on req, if we need to do analysis on historical analysis or only current, we choose an approach.
--in the model, we not using PK, we using prd_key
--filter historical data and keep current info (if end_dt is null, it is product current info)
select
	pi.prd_id,
	pi.cat_id,
	pi.prd_key,
	pi.prd_nm,
	pi.prd_cost,
	pi.prd_line,
	pi.prd_start_dt,
	pi.prd_end_dt
from silver.crm_prd_info pi
where pi.prd_end_dt is NULL; --filter out all historical data
--we don't need end_dt in our select as it is always null

select
	pi.prd_id,
	pi.cat_id,
	pi.prd_key,
	pi.prd_nm,
	pi.prd_cost,
	pi.prd_line,
	pi.prd_start_dt
from silver.crm_prd_info pi
where pi.prd_end_dt is NULL;

--join with product categories on cat_id of crm and id of erp
select * from silver.erp_px_cat_g1v2;

select
	pi.prd_id,
	pi.cat_id,
	pi.prd_key,
	pi.prd_nm,
	pi.prd_cost,
	pi.prd_line,
	pi.prd_start_dt,
	pc.cat,
	pc.subcat,
	pc.maintenance
from silver.crm_prd_info pi
left join silver.erp_px_cat_g1v2 pc on pi.cat_id = pc.id
where pi.prd_end_dt is NULL;

--check quality of these results
--1.check uniqueness

select prd_key,count(*) from (
	select
		pi.prd_id,
		pi.cat_id,
		pi.prd_key,
		pi.prd_nm,
		pi.prd_cost,
		pi.prd_line,
		pi.prd_start_dt,
		pc.cat,
		pc.subcat,
		pc.maintenance
	from silver.crm_prd_info pi
	left join silver.erp_px_cat_g1v2 pc on pi.cat_id = pc.id
	where pi.prd_end_dt is NULL
)t
group by prd_key
having count(*) > 1;
--all good

--sort the columns to logical groups to improve readability
--rename cols to give friendly names 

select
	pi.prd_id as product_id,
	pi.prd_key as product_number, --we need product_key as surrogate key later
	pi.prd_nm as product_name,
	pi.cat_id as category_id,
	pc.cat as category,
	pc.subcat as subcategory,
	pc.maintenance,
	pi.prd_cost as cost,
	pi.prd_line as product_line,
	pi.prd_start_dt as start_date
from silver.crm_prd_info pi
left join silver.erp_px_cat_g1v2 pc on pi.cat_id = pc.id
where pi.prd_end_dt is NULL

--is this dimension or fact?? DIMENSION
--since this is dimension, we go and create PK for it (the surrogate key)

select
	row_number() over (order by pi.prd_start_dt, pi.prd_key) as product_key,
	pi.prd_id as product_id,
	pi.prd_key as product_number,
	pi.prd_nm as product_name,
	pi.cat_id as category_id,
	pc.cat as category,
	pc.subcat as subcategory,
	pc.maintenance,
	pi.prd_cost as cost,
	pi.prd_line as product_line,
	pi.prd_start_dt as start_date
from silver.crm_prd_info pi
left join silver.erp_px_cat_g1v2 pc on pi.cat_id = pc.id
where pi.prd_end_dt is NULL;

--last step: CREATE OBJECT (virtual) -> create a view

create view gold.dim_products as 
select
	row_number() over (order by pi.prd_start_dt, pi.prd_key) as product_key,
	pi.prd_id as product_id,
	pi.prd_key as product_number,
	pi.prd_nm as product_name,
	pi.cat_id as category_id,
	pc.cat as category,
	pc.subcat as subcategory,
	pc.maintenance,
	pi.prd_cost as cost,
	pi.prd_line as product_line,
	pi.prd_start_dt as start_date
from silver.crm_prd_info pi
left join silver.erp_px_cat_g1v2 pc on pi.cat_id = pc.id
where pi.prd_end_dt is NULL;


-------------------------------------------------------
--quality check of gold table
select * from gold.dim_products;

--1.
select distinct category_id from gold.dim_products;

--2.
select distinct product_name from gold.dim_products where product_name != trim(product_name);

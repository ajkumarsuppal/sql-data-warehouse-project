--from data integration diagram, we find which tables belong to fact sales.
select * from silver.crm_sales_details;

--we will now select columns we need to present in gold layer.
select 
	sd.sls_ord_num,
	sd.sls_prd_key,
	sd.sls_cust_id,
	sd.sls_order_dt,
	sd.sls_ship_dt,
	sd.sls_due_dt,
	sd.sls_sales,
	sd.sls_quantity,
	sd.sls_price
from silver.crm_sales_details sd;

--is this dimension or fact?? FACT
--we see txns, we see events, lots of date informations, lot of measures and metrics, as well as a lot of ids(KEYS)-> so it is connecting multiple dimensions
--perfect setup for facts.
--as fact connects multiple dimensions, we present in this fact the SURROGATE KEYS that come from this dimensions.
--sls_prd_key, sls_cust_id are ORIGINAL IDS connecting dimensions -> so we replace these with dimension surrogate keys to easily do the connection
--THIS PROCESS IS CALLED DATA LOOKUP
--for this fact table, we will join silver with gold layers
select * from gold.dim_products;
select * from gold.dim_customers;

select 
	sd.sls_ord_num,
	p.product_key,
	c.customer_key,
	sd.sls_order_dt,
	sd.sls_ship_dt,
	sd.sls_due_dt,
	sd.sls_sales,
	sd.sls_quantity,
	sd.sls_price
from silver.crm_sales_details sd
left join gold.dim_products p on sd.sls_prd_key = p.product_number
left join gold.dim_customers c on sd.sls_cust_id=c.customer_id
where p.product_key=3;

--sort the columns to logical groups to improve readability: dimensions -> dates -> measures
--rename cols to give friendly names 

select 
	sd.sls_ord_num as order_number,
	p.product_key,
	c.customer_key,
	sd.sls_order_dt as order_date,
	sd.sls_ship_dt as shipping_date,
	sd.sls_due_dt as due_date,
	sd.sls_sales as sales_amount,
	sd.sls_quantity as quantity,
	sd.sls_price as price
from silver.crm_sales_details sd
left join gold.dim_products p on sd.sls_prd_key = p.product_number
left join gold.dim_customers c on sd.sls_cust_id=c.customer_id;

--last step: CREATE OBJECT (virtual) -> create a view

create view gold.fact_sales as
select 
	sd.sls_ord_num as order_number,
	p.product_key,
	c.customer_key,
	sd.sls_order_dt as order_date,
	sd.sls_ship_dt as shipping_date,
	sd.sls_due_dt as due_date,
	sd.sls_sales as sales_amount,
	sd.sls_quantity as quantity,
	sd.sls_price as price
from silver.crm_sales_details sd
left join gold.dim_products p on sd.sls_prd_key = p.product_number
left join gold.dim_customers c on sd.sls_cust_id=c.customer_id;

-------------------------------------------------------
--quality check of gold table

select * from gold.fact_sales;

--foreign key integrity (dimensions)
--check if all dimensions can join to fact
select * from gold.fact_sales s
left join gold.dim_customers c on s.customer_key = c.customer_key
left join gold.dim_products p on s.product_key = p.product_key
where c.customer_key is null or p.product_key is null;

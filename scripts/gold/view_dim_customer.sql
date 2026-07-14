create view gold.dim_customers as
select
row_number() over(order by ci.cst_id) as customer_key,
ci.cst_id as customer_id,
ci.cst_key as customer_number,
ci.cst_firstname as first_name,
ci.cst_lastname as last_name,
ci.cst_marital_status as marital_status,
case when ci.cst_gndr != 'n/a' then ci.cst_gndr
else coalesce(ec.gen,'n/a') end
as gender,
el.cntry as country,
ec.bdate as birthdate,
ci.cst_create_date AS create_date
from silver.crm_cust_info ci
left join silver.erp_cust_az12 ec on ec.cid = ci.cst_key
left join silver.erp_loc_a101 el on el.cid = ci.cst_key



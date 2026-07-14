create view gold.fact_sales as
SELECT sd.[sls_ord_num] as order_number
      ,dp.product_key
      ,c.customer_key
      ,sd.[sls_order_dt] as order_date
      ,sd.[sls_ship_dt] as shipping_date
      ,sd.[sls_due_dt] as due_date
      ,sd.[sls_sales] as sales_amount
      ,sd.[sls_quantity] as quantity
      ,sd.[sls_price] as price

  FROM [silver].[crm_sales_details] sd
  left join gold.dim_product dp on dp.product_number = sd.[sls_prd_key]
  left join gold.dim_customers c on c.customer_id = sd.[sls_cust_id]



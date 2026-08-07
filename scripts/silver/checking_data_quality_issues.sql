-- Checking the data quality issues of data "bronze.crm_cust_info" table.

-- Check for Nulls or Duplicates in Primary Key
-- Expectation: No Result

select cst_id, count(*) 
from bronze.crm_cust_info
group by cst_id
having count (*) > 1 or cst_id is NULL

-- check for unwanted spaces
-- Expectation: No Result

select cst_firstname
from bronze.crm_cust_info
where cst_firstname != TRIM(cst_firstname)

select cst_lastname
from bronze.crm_cust_info
where cst_lastname != TRIM(cst_lastname)

select cst_gndr
from bronze.crm_cust_info
where cst_gndr != TRIM(cst_gndr)

-- Data Standardization & Consistency
-- In our data warehouse, we aim to store clear and meaningful values rather than using abbreviated terms like F and M.
select distinct cst_gndr
from bronze.crm_cust_info

select distinct cst_marital_status
from bronze.crm_cust_info

-- Quality check of the silver table

select cst_id, count(*) 
from silver.crm_cust_info
group by cst_id
having count (*) > 1 or cst_id is NULL

select cst_firstname
from silver.crm_cust_info
where cst_firstname != TRIM(cst_firstname)

select distinct cst_gndr
from silver.crm_cust_info

select * from silver.crm_cust_info

-- Finally the data quality in silver.crm_cust_info is good no issues. 

-- Checking the data quality issues of data "bronze.crm_prd_info" table.

-- Check for Nulls or Duplicates in Primary Key
-- Expectation: No Result

select prd_id, count(*) 
from bronze.crm_prd_info
group by prd_id
having count (*) > 1 or prd_id is NULL

-- check for unwanted spaces
-- Expectation: No Result

select prd_nm
from bronze.crm_prd_info
where prd_nm != TRIM(prd_nm)

-- Check for NULLs or Negative Numbers
-- Expectation : No Results

select prd_cost
from bronze.crm_prd_info
where prd_cost < 0 OR prd_cost is null

-- Data Standardization & Consistency

select distinct prd_line
from bronze.crm_prd_info

-- check for invalid date orders (I take some rows and checked it in excel so I can understand it better)

select * from silver.crm_prd_info

-- Finally the data quality in silver.crm_prd_info is good no issues. 

-- Checking the data quality issues of data "bronze.crm_sales_details" table.

-- check for invalid dates
select 
NULLIF(sls_order_dt,0) sls_order_dt
from bronze.crm_sales_details
where sls_order_dt <= 0 
or len (sls_order_dt) != 8
or sls_order_dt > 20500101
or sls_order_dt < 19000101

select 
NULLIF(sls_ship_dt,0) sls_ship_dt
from bronze.crm_sales_details
where sls_ship_dt <= 0 
or len (sls_ship_dt) != 8
or sls_ship_dt > 20500101
or sls_ship_dt < 19000101

select 
NULLIF(sls_due_dt,0) sls_due_dt
from bronze.crm_sales_details
where sls_due_dt <= 0 
or len (sls_due_dt) != 8
or sls_due_dt > 20500101
or sls_due_dt < 19000101

-- always check order date must always be earlier than the shipping daye or due date.

select 
*
from bronze.crm_sales_details
where sls_order_dt > sls_ship_dt or sls_order_dt > sls_due_dt

-- Values must not be null, zero, or negative
-- Business Rules

-- sales = quantity * price
-- negative, zeroes, nulls are not allowed!

select distinct
sls_sales, 
sls_quantity,
sls_price
from bronze.crm_sales_details
where sls_sales != sls_quantity * sls_price
or sls_sales is null or sls_quantity is null or sls_price is null
or sls_sales <= 0 or sls_quantity <= 0 or sls_price <= 0
order by sls_sales, sls_quantity, sls_price

/* The above query have bad data by looking in the data in slaes we have nulls, negative numbers, and zeroes so all we have bad
comparisons and bad calculations so you can see in data the price is 50, quantity is 1 but the sales is 2 which is not correct 
calculations. We find issues in sales and price columns.
Offcourse what I will do it here, I don't go and transform everything on my own, I usually go to an talked to expert may be someone
from the business or from the source systems and I saw this issues or scenarios and discussed, usually there will be 2 answers :
1. Data issues will be fixed direct in source system
2. Data isues has to be fixed in data warehouse
you here we have to decide either we have to leave has it or you say you know what let's go and improve the quality of data. 

But here we have to ask expert to solving this issues and i's really depend on there rules makes difference and transformations
Rules :
If sales is negative, zero, or null, derive it using quantity and price.
If price is zero or null, calculate it using sales and quantity.
If price is negative, convert it to a positive value.

So, now we wil go and build the transformations based on the above rules.*/


select distinct
sls_sales as old_sls_sales,
sls_quantity,
sls_price as old_sls_price,
case when sls_sales is null or sls_sales <=0 or sls_sales != sls_quantity * ABS(sls_price)
	then sls_quantity * ABS(sls_price)
else sls_sales
end as sls_sales,

case when sls_price is null or sls_price <= 0
	then sls_sales / nullif(sls_quantity, 0)
else sls_price
end as sls_price
from bronze.crm_sales_details
where sls_sales != sls_quantity * sls_price
or sls_sales is null or sls_quantity is null or sls_price is null
or sls_sales <= 0 or sls_quantity <= 0 or sls_price <= 0
order by sls_sales, sls_quantity, sls_price

-- Checking the data quality issues of data "erp_cust_az12" table.

/*So in this table we have only 3 columns let's first start with id. If we check in our model(diagram) then we have to connect 
this table with crm_cust_info table using their customer key. 

Now we have to check offcouse silver table*/

select 
cid,
bdate,
gen
from bronze.erp_cust_az12

select * from silver.crm_cust_info


/* After running this above query we see in result in bronze.erp_cust_az12 there is extra characters there are not included
in the customer key in table silver.crm_cust_info. So let's go and search for this customer*/

select 
cid,
bdate,
gen
from bronze.erp_cust_az12
where cid like '%AW00011000%' -- So we are searching for customer has similar id.

/*We have issue that we have 3 extra characters like "NAS" there is no specification or explanation why we have "NAS", so 
acutally what we have to do that remove those characters (info) we don't needed.*/

-- Identify out-of-range dates

-- Check for very old customers & Check for birthdays in future.
-- While running this query you will found we will have customers who are 100 years old.

select distinct
bdate
from bronze.erp_cust_az12
where bdate < '1924-01-01' or bdate > getdate()

-- Data standardization & consistency.
-- While running this query you will found the data is not good. 
select distinct gen
from bronze.erp_cust_az12

/* Checking the data quality issues of data "bronze.erp_loc_a101" table.
here also we have to connect the cst_id of crm_cust_info with erp_loc_a101 */

-- let's go check the data
-- here what's the issue there is '-' symbol in cid of bronze.erp_loc_a101 which will creat issue, we can't able to join tables.
select 
cid,
cntry
from bronze.erp_loc_a101

select cst_key from silver.crm_cust_info

-- Data standardization & consistency.
-- We will find that the quality of country is not good like United states or USA or US.
select distinct cntry
from bronze.erp_loc_a101
order by cntry

/* Checking the data quality issues of data "bronze.erp_px_cat_g1v2" table.
here also we have to connect the cat_id of erp_px_cat_g1v2 with crm_prd_info */

-- check for unwanted spaces
select * from bronze.erp_px_cat_g1v2
where cat != trim(cat) or subcat != trim(subcat) or maintenance != trim(maintenance)

-- data standardization & consistency
select distinct
cat
from bronze.erp_px_cat_g1v2

select distinct
subcat
from bronze.erp_px_cat_g1v2

select distinct
maintenance
from bronze.erp_px_cat_g1v2

-- good news this table has a really nice data quality no need to transform(clean up) the data of this table. 

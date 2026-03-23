--CREATING TABLES

drop table if exists city;
create table city (
city_id	   int PRIMARY KEY,
city_name   varchar(50),
population    bigint,
estimated_rent  float,
city_rank      int
);

drop table if exists customers;
create table customers (
customer_id	   int PRIMARY KEY,
customer_name  varchar(60),
city_id        int  
);

drop table if exists products;
create table products (
product_id    int PRIMARY KEY,
product_name  varchar(300),
price      float     
);

drop table if exists sales;
create table sales (
sale_id     int PRIMARY KEY,
sale_date	DATE,
product_id	int,
customer_id  int,
total        float,
rating       int
);

alter table customers
add constraint fk_city
foreign key (city_id)
references city(city_id);

alter table sales
add constraint fk_customers
foreign key (customer_id)
references customers(customer_id);

alter table sales
add constraint fk_products
foreign key (product_id)
references products(product_id)
on delete cascade
on update cascade;

select * from city;
select * from customers;
select * from products;
select * from sales;

-- Reports & Data Analysis
--Q1. Coffee Consumers Count
--How many people in each city are estimated to consume coffee, given that 25% of the population does?
select * from city;
select city_name, 
ROUND(
(population * 0.25)/1000000,2), city_rank from city
order by 2 desc;

--Q2.Total Revenue from Coffee Sales
--What is the total revenue generated from coffee sales across all cities in the last quarter of 2023?
select * from sales;

select 
sum(total) as total_revenue
FROM SALES
WHERE
EXTRACT(YEAR FROM sale_date) = 2023
AND
EXTRACT(quarter FROM sale_date) = 4;

--Q3.Sales Count for Each Product
--How many units of each coffee product have been sold?

select  product_name , count(sale_id)
from products as p 
JOIN sales as s
ON p.product_id = s.product_id
group by 1
order by 2 desc;

--Q4.Average Sales Amount per City
--What is the average sales amount per customer in each city?

select city_name , sum(total) as total,count(DISTINCT s.customer_id) as count,
ROUND (
sum(total)::numeric / count(DISTINCT s.customer_id)::numeric,2) as avg_sales
FROM city as c
JOIN customers as cus
ON c.city_id = cus.city_id 
JOIN sales as s
ON s.customer_id = cus.customer_id
group by 1
order by 2 desc;

--Q5.City Population and Coffee Consumers
--Provide a list of cities along with their populations and estimated coffee consumers.

WITH city_table 
AS
(select city_name , ROUND((population * 0.25)/1000000, 2) as coffee_consumers
FROM  city) , 
customers_table
AS
(select city_name, count(DISTINCT s.customer_id) as unique_cx
FROM city as c
JOIN customers as cu
ON c.city_id = cu.city_id
JOIN sales as s
ON s.customer_id = cu.customer_id
group by 1)

select cit.city_name, coffee_consumers, ct.unique_cx from city_table as cit
JOIN customers_table as ct
ON ct.city_name = cit.city_name;

--Q6.Top Selling Products by City
--What are the top 3 selling products in each city based on sales volume?
select * from sales;

SELECT * 
FROM 
(
	SELECT ci.city_name,p.product_name,
		COUNT(s.sale_id) as total_orders,
		DENSE_RANK() OVER(PARTITION BY ci.city_name ORDER BY COUNT(s.sale_id) DESC) as rank
	FROM sales as s
	JOIN products as p
	ON s.product_id = p.product_id
	JOIN customers as c
	ON c.customer_id = s.customer_id
	JOIN city as ci
	ON ci.city_id = c.city_id
	GROUP BY 1, 2
) as t1
WHERE rank <= 3

--Q7.Customer Segmentation by City
--How many unique customers are there in each city who have purchased coffee products?
select city_name,
COUNT(DISTINCT cus.customer_id) as unique_cx
FROM city as c
JOIN customers as cus
ON c.city_id = cus.city_id
JOIN sales as s
ON s.customer_id = cus.customer_id
WHERE s.product_id IN(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14)
group by 1;

--Q8.Average Sale vs Rent
--Find each city and their average sale per customer and avg rent per customer
select * from city;


WITH city_table
AS
(select city_name, sum(total) as total , COUNT(DISTINCT s.customer_id) as unique_cx, 
ROUND (
sum(total)::numeric / COUNT(DISTINCT s.customer_id)::numeric, 2
) as avg_sales

FROM city as c
JOIN customers as cus
ON c.city_id = cus.city_id 
JOIN sales as s
ON s.customer_id = cus.customer_id
group by 1
order by 2 desc),

city_rent AS
(select city_name, estimated_rent 
FROM city
)
select  cr.city_name ,
cr.estimated_rent, 
ct.unique_cx,
ct.avg_sales , 
ROUND(
cr.estimated_rent::numeric /
ct.unique_cx::numeric , 2) as avg_rent_per_cx
FROM city_rent as cr
JOIN city_table as ct
ON cr.city_name = ct.city_name
order by avg_sales desc;

-----(OR)----

WITH city_table
AS
(select city_name, sum(total) as total , COUNT(DISTINCT s.customer_id) as unique_cx, 
ROUND (
sum(total)::numeric / COUNT(DISTINCT s.customer_id)::numeric, 2
) as avg_sales , c.estimated_rent , 
ROUND (
c.estimated_rent ::numeric / COUNT(DISTINCT s.customer_id)::numeric, 2
) as avg_rent

FROM city as c
JOIN customers as cus
ON c.city_id = cus.city_id 
JOIN sales as s
ON s.customer_id = cus.customer_id
group by 1,c.estimated_rent 
order by 2 desc)

select city_name,ct.estimated_rent,unique_cx, avg_sales, avg_rent
FROM city_table as ct;

--Q9.Monthly Sales Growth
--Sales growth rate: Calculate the percentage growth (or decline) in sales over different time periods (monthly).
WITH
monthly_sales
AS
(
	SELECT 
		ci.city_name,
		EXTRACT(MONTH FROM sale_date) as month,
		EXTRACT(YEAR FROM sale_date) as YEAR,
		SUM(s.total) as total_sale
	FROM sales as s
	JOIN customers as c
	ON c.customer_id = s.customer_id
	JOIN city as ci
	ON ci.city_id = c.city_id
	GROUP BY 1, 2, 3
	ORDER BY 1, 3, 2
),
growth_ratio
AS
(
SELECT city_name,month,year,total_sale as cr_month_sale,
		LAG(total_sale, 1) OVER(PARTITION BY city_name ORDER BY year, month) as last_month_sale
		FROM monthly_sales
)

SELECT
	city_name,
	month,
	year,
	cr_month_sale,
	last_month_sale,
	ROUND(
		(cr_month_sale-last_month_sale)::numeric/last_month_sale::numeric * 100
		, 2
		) as growth_ratio

FROM growth_ratio
WHERE 
	last_month_sale IS NOT NULL	

--Q10. Market Potential Analysis
-- Identify top 3 city based on highest sales, return city name, total sale, total rent, total customers, estimated coffee consumer
select * from city;

WITH city_table
AS
(
select city_name, sum(total) as total_revenue, COUNT(DISTINCT s.customer_id) as total_cx,
ROUND(
 sum(total)::numeric / COUNT(DISTINCT s.customer_id)::numeric,2) as avg_sales_per_cx
FROM city as c
JOIN customers as cus
on c.city_id = cus.city_id
JOIN sales as s
ON s.customer_id = cus.customer_id
group by 1
order by 2 desc
), 
city_rent AS
(
select city_name,estimated_rent,
ROUND(
(population * 0.25 / 1000000),3) as coffee_consumers_in_millions
FROM city 
)
select ct.city_name, 
       total_revenue, 
       cr.estimated_rent as total_rent,
	   ct.total_cx, 
	   coffee_consumers_in_millions,
	   ct.avg_sales_per_cx,
	   ROUND(
	   cr.estimated_rent::numeric / ct.total_cx::numeric, 2) as avg_rent_per_cx
FROM city_table as ct
JOIN city_rent as cr
ON ct.city_name = cr.city_name
order by total_revenue desc;



























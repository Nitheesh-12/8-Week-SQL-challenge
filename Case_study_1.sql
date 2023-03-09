USE dannys_diner;

#1 What is the total amount each customer spent at the restaurant?
SELECT customer_id, sum(price) AS amt_spent
FROM sales
JOIN menu 
ON sales.product_id = menu.product_id
GROUP BY Customer_id;

#2 How many days has each customer visited the restaurant?
SELECT Customer_id, count(DISTINCT order_date) AS total_visits
FROM sales
GROUP BY customer_id;

#3 What was the first item from the menu purchased by each customer?
SELECT DISTINCT Customer_id,order_date, product_name AS first_ordered_item
FROM (SELECT customer_id,product_name,
DENSE_RANK() OVER (PARTITION BY customer_id ORDER BY order_date) AS rn
FROM sales
JOIN menu
ON sales.product_id = menu.product_id) AS temp
WHERE rn = 1;

#4 What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT product_name AS most_purchased_item, count(sales.product_id) AS cnt_orders
FROM sales
JOIN menu ON sales.product_id = menu.product_id
GROUP BY  product_name
ORDER BY cnt_orders DESC
LIMIT 1;

#5 Which item was the most popular for each customer?
SELECT customer_id, product_name, num_orders
FROM (SELECT customer_id, product_name, count(menu.product_name) AS num_orders, 
DENSE_RANK() OVER (PARTITION BY customer_id ORDER BY count(product_name) DESC) AS dr
FROM sales
JOIN menu ON sales.product_id = menu.product_id
GROUP BY customer_id, product_name) AS temp
WHERE dr =1 ;

#6 Which item was purchased first by the customer after they became a member?
SELECT sales.customer_id, menu.product_name, order_date,join_date
FROM (sales
JOIN members
ON sales.customer_id = members.customer_id
JOIN menu 
ON sales.product_id = menu.product_id)
WHERE order_date >= join_date
LIMIT 2;

#7 Which item was purchased just before the customer became a member?
SELECT customer_id, product_name, order_date, join_date
FROM 
(SELECT sales.*,product_name,join_date,
DENSE_RANK() OVER (PARTITION BY sales.customer_id ORDER BY  order_date DESC) AS rnk
FROM sales
JOIN members
ON sales.customer_id = members.customer_id
JOIN menu 
ON sales.product_id = menu.product_id
WHERE order_date < join_date ) AS temp
WHERE rnk = 1;

#8 What is the total items and amount spent for each member before they became a member?
SELECT sales.customer_id,count(sales.product_id) AS cnt, sum(price) AS total
FROM sales
JOIN menu
ON sales.product_id = menu.product_id
JOIN members
ON sales.customer_id = members.customer_id
WHERE order_date<join_date
GROUP BY sales.customer_id;

/*9 If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points 
would each customer have?*/
SELECT customer_id, sum(cnt*pnt) AS points
FROM
(SELECT sales.customer_id,sales.product_id,count(sales.product_id) AS cnt,
IF (sales.product_id = 1,price*20,price*10) AS pnt
FROM sales
JOIN menu
ON sales.product_id = menu.product_id
GROUP BY sales.customer_id, sales.product_id) AS tem
GROUP BY customer_id;

/*10 In the first week after a customer joins the program (including their join date) they earn 2x 
points on all items, not just sushi - how many points do customer A and B have at the end of January?*/
SELECT customer_id, sum(points) AS total_points
FROM (SELECT members.customer_id, join_date, order_date, menu.product_name, price, 
      CASE WHEN (order_date BETWEEN join_date AND date_add(join_date,INTERVAL 6 DAY)) THEN price*20
		   WHEN (order_date NOT BETWEEN join_date AND date_add(join_date, INTERVAL 6 DAY) AND product_name = "sushi") THEN price*20
		   ELSE price*10
		   END AS points
FROM sales
JOIN members ON sales.customer_id = members.customer_id
JOIN menu ON sales.product_id = menu.product_id) as temp
group by customer_id;

# BONUS QUESTIONS
 #1 
 SELECT sales.customer_id, order_date, product_name,price, IF (order_date >= join_date,"Y","N") as member
 FROM sales
 LEFT JOIN members ON sales.customer_id = members.customer_id
 LEFT JOIN menu ON sales.product_id = menu.product_id;
 #2 
WITH cte as (SELECT sales.customer_id, order_date, product_name,price, IF (order_date >= join_date,"Y","N") as member
 FROM sales
 LEFT JOIN members ON sales.customer_id = members.customer_id
 LEFT JOIN menu ON sales.product_id = menu.product_id)
 SELECT *, CASE WHEN member = "N" THEN NULL
				ELSE RANK() OVER(PARTITION BY customer_id, member ORDER BY order_date) 
                END AS ranking
FROM cte;
 
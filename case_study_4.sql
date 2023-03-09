# A. Customer Nodes Exploration
#1 How many unique nodes are there on the Data Bank system?

WITH CTE AS (
SELECT region_id, count(DISTINCT node_id) AS nodes
FROM customer_nodes
GROUP BY region_id)
SELECT sum(nodes) AS total_nodes
FROM CTE;

#2 What is the number of nodes per region?

SELECT region_id, count(node_id) as node_count
FROM customer_nodes
GROUP BY region_id
ORDER BY region_id;

#3 How many customers are allocated to each region?

SELECT region_id, count(DISTINCT customer_id) as node_count
FROM customer_nodes
GROUP BY region_id
ORDER BY region_id;

#4 How many days on average are customers reallocated to a different node?

WITH CTE AS (
SELECT customer_id,node_id, datediff(end_date,start_date) as diff
FROM customer_nodes
WHERE end_date != '9999-12-31'
GROUP BY customer_id, node_id, start_date,end_date
ORDER BY customer_id,node_id) 
SELECT round(avg(diff)) AS avg_reallocation_days FROM CTE;


#B Customer Transactions
#1 What is the unique count and total amount for each transaction type?

SELECT txn_type, count(*) AS count, sum(txn_amount) AS total_amount
FROM customer_transactions
GROUP BY txn_type
ORDER BY txn_type;

#2 What is the average total historical deposit counts and amounts for all customers?

WITH total_deposit_amounts AS ( SELECT customer_id, count(*) AS deposits_count, avg(txn_amount) AS total_deposit_amount
								FROM customer_transactions
								WHERE txn_type = 'deposit'
								GROUP BY customer_id)
SELECT round(avg(deposits_count)) AS avg_deposit_count, round(avg(total_deposit_amount)) AS avg_deposit_amount
FROM total_deposit_amounts;

#3 For each month - how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?

WITH get_all_transactions_count AS (
	SELECT DISTINCT customer_id, monthname(txn_date) AS current_month,
		sum( CASE WHEN txn_type = 'purchase' THEN 1
				  ELSE NULL
				  END  ) AS purchase_count,
		sum( CASE WHEN txn_type = 'withdrawal' THEN 1
				  ELSE NULL
			      END  ) AS withdrawal_count,
		sum( CASE WHEN txn_type = 'deposit' THEN 1
				  ELSE NULL
			      END  ) AS deposit_count
	FROM customer_transactions
	GROUP BY customer_id, current_month)
SELECT current_month, count(customer_id) AS customer_count
FROM get_all_transactions_count
WHERE deposit_count > 1 AND (purchase_count >= 1 OR withdrawal_count >= 1)
GROUP BY current_month
ORDER BY month(current_month);

#4 What is the closing balance for each customer at the end of the month?
WITH temp AS (SELECT customer_id, monthname(txn_date),max(txn_date) as max_date, 
SUM( CASE WHEN txn_type = 'deposit' THEN txn_amount ELSE -txn_amount END) AS cte
FROM customer_transactions
GROUP BY customer_id, monthname(txn_date)
ORDER BY customer_id, monthname(txn_date)
limit 15)
, temp1 AS (SELECT *, lag(cte) over(partition by customer_id order by month(txn_date) FROM temp)
SELECT * FROM temp1;
#5 
WITH minimum AS (
select
	n.customer_id,
	month(t.txn_date) month_id,
	monthname(t.txn_date) month_name,
	count(t.txn_type) total
from customer_transactions t
left join customer_nodes n on t.customer_id = n.customer_id
left join regions r on n.region_id = r.region_id
group by n.customer_id, month(t.txn_date), monthname(t.txn_date))
select 
  ROUND(100 * CAST(COUNT(customer_id) as float) / 
			(select count(*) from customer_transactions), 2) percentage_of_customers
from minimum
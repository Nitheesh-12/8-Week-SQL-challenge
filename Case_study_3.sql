# A 
#1 Distinct customer_id in the dataset
SELECT count(distinct(customer_id)) AS 'distinct customers'
FROM subscriptions;

/* 2 Selecting the following random customer_id's from the subscriptions table to view their onboarding journey. Checking the 
following customer_id's : 1,87,99,193,290,400 */
SELECT customer_id, plan_id, plan_name, Start_date
FROM subscriptions 
JOIN plans USING (plan_id)       # Customer started the free trial on 1 August 2020
WHERE customer_id = 1;          # They subscribed to the basic monthly during the seven day the trial period to continue the subscription

SELECT customer_id, plan_id, plan_name, Start_date
FROM subscriptions 
JOIN plans USING (plan_id)       
WHERE customer_id = 87;      /* Customer started the free trial on 8 August 2020
                                 They may have chosen to continue with the pro monthly after the seven day the trial period
                                 They then upgraded to the pro annual plan in September 2020 */
                                 
SELECT customer_id, plan_id, plan_name, Start_date
FROM subscriptions 
JOIN plans USING (plan_id)       
WHERE customer_id = 99;       /* Customer started the free trial on 5 December 2020
                                 They chose not to continue with paid subscription and decided to cancel on the last day of the trial period. */                  
                                 
SELECT customer_id, plan_id, plan_name, Start_date
FROM subscriptions 
JOIN plans USING (plan_id)       
WHERE customer_id = 290;    /* Customer started the free trial on 10 January 2020
                               They subscribed to the basic monthly plan during the seven day the trial period to continue the subscription */                               
       
SELECT customer_id, plan_id, plan_name, Start_date
FROM subscriptions 
JOIN plans USING (plan_id)       
WHERE customer_id = 400;        /* Customer started the free trial on 27 February 2020
                               They subscribed to the basic monthly plan during the seven day the trial period to continue the subscription */ 
                
                
# B 
#1 How many customers has Foodie-Fi ever had?
SELECT count(DISTINCT customer_id)
FROM subscriptions;

#2 What is the monthly distribution of trial plan start_date values for our dataset - use the start of the month as the group by value
SELECT month(Start_date), count(DISTINCT customer_id) AS "monthly_distribution"
FROM subscriptions
JOIN plans USING (plan_id)
WHERE plan_id = 0
GROUP BY month(start_date);

#3 What plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of events for each plan_name
SELECT plan_id, plan_name, Start_date, count(*) AS 'count of events'
FROM subscriptions
JOIN plans USING (plan_id)
WHERE year(start_date) > 2020
GROUP BY plan_id
ORDER BY plan_id;

#4 What is the customer count and percentage of customers who have churned rounded to 1 decimal place?
SELECT count(DISTINCT customer_id) AS customers_churned, 
round(100* count(DISTINCT customer_id)/(SELECT count(DISTINCT customer_id) FROM subscriptions),1) AS churned_percent
FROM subscriptions 
WHERE plan_id = 4;


#5 How many customers have churned straight after their initial free trial - what percentage is this rounded to the nearest whole number?
WITH churned_after_trial AS(
  SELECT customer_id, CASE WHEN plan_id = 4 AND LAG(plan_id) OVER (PARTITION BY customer_id ORDER BY start_date) = 0 THEN 1
                      ELSE 0
                      END AS is_churned
  FROM subscriptions)
SELECT SUM(is_churned) as churned_customers, FLOOR(SUM(is_churned) / COUNT(DISTINCT customer_id) * 100) as churn_perct
FROM churned_after_trial;

#6 What is the number and percentage of customer plans after their initial free trial?
WITH plans_after_trial AS( SELECT plan_id, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY start_date) as plan_order
                            FROM subscriptions
                            WHERE plan_id <> 0)
SELECT p2.plan_name, COUNT(p1.plan_id) AS plans_after_trial,
COUNT(p1.plan_id) /(SELECT COUNT(DISTINCT customer_id) FROM subscriptions) * 100 AS percentage
FROM plans_after_trial p1
JOIN plans p2
ON p1.plan_id = p2.plan_id
WHERE p1.plan_order = 1
GROUP BY p2.plan_name;

#7 What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?

WITH latest_plan_cte AS (SELECT *, row_number() over(PARTITION BY customer_id ORDER BY start_date DESC) AS latest_plan
                         FROM subscriptions
                         JOIN plans USING (plan_id)
                         WHERE start_date <='2020-12-31' )
SELECT plan_id, plan_name, count(customer_id) AS customer_count, round(100*count(customer_id) / (SELECT COUNT(DISTINCT customer_id)
       FROM subscriptions), 2) AS percentage_breakdown
FROM latest_plan_cte
WHERE latest_plan = 1
GROUP BY plan_id
ORDER BY plan_id;

#8 How many customers have upgraded to an annual plan in 2020?
SELECT plan_id, count(customer_id) AS annual_plan_customers
FROM subscriptions 
WHERE plan_id = 3 and YEAR(start_date) = 2020;

#9 How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?
WITH annual_customers AS( SELECT customer_id, plan_id, start_date AS annual_start_date
                          FROM subscriptions
                          WHERE plan_id = 3)
SELECT round(AVG(datediff(c.annual_start_date, s.start_date)),2) AS average_days
FROM subscriptions s
JOIN annual_customers c USING(customer_id)
WHERE s.plan_id = 0;

#10 Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)
WITH trial_plan AS( SELECT customer_id, start_date AS trail_date
                    FROM subscriptions
                    WHERE plan_id = 0),
annual_plan AS( SELECT customer_id, start_date AS annual_date
                FROM subscriptions
                WHERE plan_id = 3),
day_period AS( SELECT tp.customer_id, trail_date, annual_date, DATEDIFF(annual_date, trail_date) AS diff
            FROM trial_plan tp
            LEFT JOIN annual_plan ap USING (customer_id)
            WHERE annual_date IS NOT NULL),
bins AS ( SELECT *, floor(diff/30) AS bin
          FROM day_period)
SELECT CONCAT((bin * 30) + 1, ' - ', (bin + 1) * 30, ' days') AS days, COUNT(diff) as total_customers, 
       round(AVG(DATEDIFF( annual_date, trail_date)),2) as average_days
FROM bins
GROUP BY bin
ORDER BY bin;

#11 How many customers downgraded from a pro monthly to a basic monthly plan in 2020
WITH downgraded_customers AS( SELECT CASE WHEN plan_id = 2 AND LEAD(plan_id) OVER (PARTITION BY customer_id ORDER BY start_date) = 1 
                                          THEN 1
                                          ELSE 0
                                          END as is_downgraded
                              FROM subscriptions)
SELECT SUM(is_downgraded) AS total_downgrads
FROM downgraded_customers;



#c


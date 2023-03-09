USE pizza_runner;
# A. Pizza Metrics
#1 How many pizzas were ordered?
SELECT COUNT(*) AS total_orders 
FROM customer_orders;

#2 How many unique customer orders were made?
SELECT COUNT(DISTINCT Order_id) AS Unique_orders 
FROM customer_orders;

#3 How many successful orders were delivered by each runner?
SELECT runner_id, COUNT(pickup_time) as successful_orders
FROM runner_orders
WHERE pickup_time!=0
GROUP BY runner_id;

#4 How many of each type of pizza was delivered?
SELECT pizza_name, COUNT(c.pizza_id) AS delivered_pizza_count
FROM customer_orders c
JOIN pizza_names p
ON c.pizza_id = p.pizza_id
JOIN runner_orders r
ON c.order_id = r.order_id
WHERE  r.distance!=0
GROUP BY pizza_name;

#5 How many Vegetarian and Meatlovers were ordered by each customer?
SELECT customer_id, SUM(CASE WHEN pizza_id = 1 THEN 1
                             ELSE 0
                             END) AS 'Meat lover Pizza Count',
                    SUM(CASE WHEN pizza_id = 2 THEN 1
                             ELSE 0
                             END) AS 'Vegetarian Pizza Count'
FROM customer_orders_temp
GROUP BY customer_id
ORDER BY customer_id;

#6 What was the maximum number of pizzas delivered in a single order?
SELECT customer_id,
       order_id,
       count(order_id) AS pizza_count
FROM customer_orders
GROUP BY order_id
ORDER BY pizza_count DESC
LIMIT 1;

#7 For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
SELECT customer_id, SUM(CASE WHEN (exclusions <> '' OR extras <> '' ) THEN 1
                             ELSE 0
                             END ) AS atleast_one_change,
	SUM(CASE WHEN (exclusions IS NULL AND extras IS NULL )THEN 1
			 ELSE 0
             END ) AS no_change
FROM customer_orders_temp AS c
JOIN runner_orders_temp AS r
ON c.order_id = r.order_id
WHERE r.distance != 0
GROUP BY c.customer_id
ORDER BY c.customer_id;

#8 How many pizzas were delivered that had both exclusions and extras?
SELECT	customer_id, SUM(CASE WHEN exclusions IS NOT NULL AND extras IS NOT NULL THEN 1
			 ELSE 0
             END ) AS pizza_count_w_exclusions_extras
FROM customer_orders_temp AS c
JOIN runner_orders_temp AS r
ON c.order_id = r.order_id
WHERE r.distance != 0
GROUP BY customer_id
ORDER BY customer_id;

#9 What was the total volume of pizzas ordered for each hour of the day?
SELECT HOUR( order_time) AS hour_of_day, COUNT(order_id) AS pizza_count, 
ROUND(100*COUNT(order_id) /SUM(COUNT(order_id)) OVER(), 2) AS 'Volume of pizzas ordered'
FROM customer_orders_temp
GROUP BY hour_of_day
ORDER BY hour_of_day;

#10 What was the volume of orders for each day of the week?
SELECT dayname( order_time) AS Day_of_Week, COUNT(order_id) AS pizza_count, 
ROUND(100*COUNT(order_id) /SUM(COUNT(order_id)) OVER(), 2) AS 'Volume of pizzas ordered'
FROM customer_orders
GROUP BY Day_of_Week
ORDER BY Day_of_Week DESC;

# B. Runner and customer experience

#1 How many runners signed up for each 1 week period? 
SELECT WEEK(registration_date) AS registration_Week,
COUNT(runner_id) AS no_runner
FROM runners
GROUP BY registration_week;

#2 What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
SELECT runner_id, ROUND(AVG(TIMESTAMPDIFF(MINUTE,c.order_time, r.pickup_time)),2) AS avg_runner_pick_time
FROM customer_orders c 
JOIN runner_orders r
ON c.order_id = r.order_id 
GROUP BY runner_id;

#3 Is there any relationship between the number of pizzas and how long the order takes to prepare?
WITH cte AS (SELECT c.order_id,COUNT(c.order_id) AS pizza_order_count, TIMESTAMPDIFF(MINUTE,c.order_time, r.pickup_time) AS prep_time
FROM customer_orders_temp c 
INNER JOIN runner_orders_temp r
ON c.order_id = r.order_id 
GROUP BY order_id)
SELECT pizza_order_count, ROUND(AVG(prep_time),2)
FROM cte
GROUP BY pizza_order_count;

#4 What was the average distance travelled for each customer?
SELECT customer_id, ROUND(AVG(distance),2) AS avg_distance_travelled
FROM customer_orders c
JOIN runner_orders r 
ON c.order_id = r.order_id
WHERE r.duration != 0
GROUP BY customer_id;

#5 What was the difference between the longest and shortest delivery times for all orders?
SELECT MIN(duration) AS minimum_duration,
       MAX(duration) AS maximum_duration,
       MAX(duration) - MIN(duration) AS maximum_difference
FROM runner_orders_temp
WHERE duration!=0;

#6 What was the average speed for each runner for each delivery and do you notice any trend for these values?
SELECT runner_id,
       distance AS distance_km,
       round(duration/60, 2) AS duration_hr,
       round(distance*60/duration, 2) AS speed
FROM runner_orders_temp
WHERE cancellation IS NULL
ORDER BY runner_id;

#7 What is the successful delivery percentage for each runner?
SELECT runner_id,
       COUNT(pickup_time) AS delivered_orders,
       COUNT(*) AS total_orders,
       ROUND(100 * COUNT(pickup_time) / COUNT(*)) AS delivery_success_percentage
FROM runner_orders_temp
GROUP BY runner_id
ORDER BY runner_id;

# C Ingredient Optimisation WIP

#1 What are the standard ingredients for each pizza?
SELECT *
FROM standard_ingredients;

#2 What was the most commonly added extra?
WITH cte AS (SELECT extras, COUNT(*) AS purchase_count
FROM row_split_customer_orders_temp
WHERE extras IS NOT NULL
GROUP BY extras)
SELECT topping_name,
       purchase_count
FROM cte
INNER JOIN pizza_toppings ON cte.extras= pizza_toppings.topping_id
LIMIT 1;

#3 What was the most common exclusion?
WITH cte AS (SELECT exclusions, COUNT(*) AS purchase_count
FROM row_split_customer_orders_temp
WHERE exclusions IS NOT NULL
GROUP BY exclusions)
SELECT topping_name,
       purchase_count
FROM cte
INNER JOIN pizza_toppings ON cte.exclusions= pizza_toppings.topping_id
LIMIT 1;

/* 4 Generate an order item for each record in the customers_orders table in the format of one of the following:
Meat Lovers
Meat Lovers - Exclude Beef
Meat Lovers - Extra Bacon
Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers */
WITH order_summary_cte AS
  (SELECT pizza_name, row_num, order_id, customer_id, excluded_topping, t2.topping_name AS extras_topping
   FROM (SELECT *,topping_name AS excluded_topping
         FROM row_split_customer_orders_temp
         LEFT JOIN standard_ingredients USING (pizza_id)
         LEFT JOIN pizza_toppings ON topping_id = exclusions) t1
        LEFT JOIN pizza_toppings t2 ON t2.topping_id = extras)
SELECT order_id,customer_id,CASE WHEN excluded_topping IS NULL AND extras_topping IS NULL THEN pizza_name
                                 WHEN extras_topping IS NULL AND excluded_topping IS NOT NULL 
                                 THEN concat(pizza_name, ' - Exclude ', GROUP_CONCAT(DISTINCT excluded_topping))
                                 WHEN excluded_topping IS NULL AND extras_topping IS NOT NULL 
                                 THEN concat(pizza_name, ' - Include ', GROUP_CONCAT(DISTINCT extras_topping))
           ELSE concat(pizza_name, ' - Include ', GROUP_CONCAT(DISTINCT extras_topping), ' - Exclude ', GROUP_CONCAT(DISTINCT excluded_topping))
           END AS order_item
FROM order_summary_cte
GROUP BY row_num;

/* 5 Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer orders table 
and add a 2x in front of any relevant ingredients */
WITH relevant_ingredients AS (SELECT pizza_recipes_temp.*, pizza_name, topping_name, topping_id
                              FROM pizza_recipes_temp JOIN pizza_names USING (pizza_id)
                              JOIN pizza_toppings ON pizza_toppings.topping_id = pizza_recipes_temp.topping)
SELECT order_id, customer_id, pizza_id,extras, exclusions, CONCAT(pizza_name,' : ', IFNULL(GROUP_CONCAT(DISTINCT extra_topping_name),''),' 2X ',
GROUP_CONCAT(DISTINCT topping_name ORDER BY topping_name)) ingredient_list
FROM( SELECT customer_orders_temp.*, pizza_name, relevant_ingredients.topping_id, relevant_ingredients.topping_name, pizza_toppings.topping_name AS extra_topping_name
      FROM customer_orders_temp JOIN relevant_ingredients USING(pizza_id)
      LEFT JOIN pizza_toppings ON LEFT(customer_orders_temp.extras,1) = pizza_toppings.topping_id
      OR RIGHT(customer_orders_temp.extras,1) = pizza_toppings.topping_id
      WHERE exclusions <> relevant_ingredients.topping_id OR exclusions IS NULL) temp
GROUP BY order_id, pizza_id, exclusions;

#6 What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?
WITH cte AS ( SELECT topping_id, topping_name, order_time, COUNT(topping) AS quantity_as_std_ingredient
              FROM customer_orders_temp JOIN pizza_recipes_temp USING(pizza_id)
              JOIN pizza_toppings ON pizza_recipes_temp.topping = pizza_toppings.topping_id
              JOIN runner_orders_temp USING(order_id)
              WHERE cancellation IS NULL
              GROUP BY topping_name, topping), 
    extra AS ( SELECT extras, COUNT(extras) AS quantity_extras
                FROM customer_orders_temp JOIN runner_orders_temp USING(order_id)
                WHERE cancellation IS NULL AND extras IS NOT NULL
                GROUP BY extras),
    exclusion AS ( SELECT exclusions, COUNT(exclusions) AS quantity_exclusions
                   FROM customer_orders_temp JOIN runner_orders_temp USING(order_id)
                   WHERE cancellation IS NULL AND exclusions IS NOT NULL
                   GROUP BY exclusions)
SELECT topping_id, topping_name, IFNULL(quantity_extras,0) count_extras, IFNULL(quantity_exclusions,0) count_exclusions,
( quantity_as_std_ingredient + IFNULL(quantity_extras,0) - IFNULL(quantity_exclusions,0)) actual_quantity   
FROM cte LEFT JOIN extra ON cte.topping_id = extra.extras
LEFT JOIN exclusion ON cte.topping_id = exclusion.exclusions
ORDER BY order_time DESC;



# D Pricing and Ratings

/* 1 If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - how much money has 
Pizza Runner made so far if there are no delivery fees?*/
SELECT CONCAT('$', SUM(CASE WHEN pizza_id = 1 THEN 12 
                            ELSE 10
                            END)) AS total_revenue
FROM customer_orders_temp
INNER JOIN pizza_names USING (pizza_id)
INNER JOIN runner_orders_temp USING (order_id)
WHERE cancellation IS NULL;

#2. What if there was an additional $1 charge for any pizza extras? Add cheese is $1 extra
SELECT CONCAT('$', topping_revenue + pizza_revenue) AS total_revenue
FROM (SELECT SUM(CASE WHEN pizza_id = 1 THEN 12
                      ELSE 10
                      END) AS pizza_revenue, sum(topping_count) AS topping_revenue
      FROM (SELECT *, length(extras) - length(replace(extras, ",", "")) +1 AS topping_count
            FROM customer_orders_temp
            INNER JOIN pizza_names USING (pizza_id)
            INNER JOIN runner_orders_temp USING (order_id)
            WHERE cancellation IS NULL
            ORDER BY order_id)t1) t2;
            
/* 3  The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, how would you design an 
additional table for this new dataset - generate a schema for this new table and insert your own data for ratings for each successful customer 
order between 1 to 5.*/
CREATE TABLE runner_rating (order_id INTEGER, rating INTEGER, review VARCHAR(100)) ;
INSERT INTO runner_rating
VALUES ('1', '1', 'Really bad service'),
       ('2', '1', NULL),
       ('3', '4', 'Took too long...'),
       ('4', '1','Runner was lost, delivered it after an hour. Pizza arrived cold' ),
       ('5', '2', 'Good service'),
       ('7', '5', 'It was great, good service and fast'),
       ('8', '2', 'He tossed it on the doorstep, poor service'),
       ('10', '5', 'Delicious!, he delivered it sooner than expected too!');
SELECT * 
FROM runner_rating;

/* 4. Using your newly generated table - can you join all of the information together to form a table which has the following information for successful deliveries?
customer_id, order_id, runner_id, rating, order_time, pickup_time, Time between order and pickup, Delivery duration, Average speed, Total number of pizzas */
SELECT customer_id, order_id, runner_id, rating, order_time, pickup_time, TIMESTAMPDIFF(MINUTE, order_time, pickup_time) pick_up_time, duration AS delivery_duration,
ROUND(distance*60/duration, 2) AS average_speed, COUNT(pizza_id) AS total_pizza_count
FROM customer_orders_temp
INNER JOIN runner_orders_temp USING (order_id)
INNER JOIN runner_rating USING (order_id)
GROUP BY order_id ;


/* 5. If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner is paid $0.30 per kilometre traveled - 
how much money does Pizza Runner have left over after these deliveries? */
SELECT concat('$', round(sum(pizza_cost-delivery_cost), 2)) AS pizza_runner_revenue
FROM (SELECT order_id, distance, SUM(pizza_cost) AS pizza_cost, ROUND(0.30*distance, 2) AS delivery_cost
      FROM (SELECT *, (CASE WHEN pizza_id = 1 THEN 12
                            ELSE 10
                            END) AS pizza_cost
            FROM customer_orders_temp
            INNER JOIN pizza_names USING (pizza_id)
            INNER JOIN runner_orders_temp USING (order_id)
            WHERE cancellation IS NULL
            ORDER BY order_id) t1
            GROUP BY order_id
            ORDER BY order_id) t2;
            
/* E If Danny wants to expand his range of pizzas - how would this impact the existing data design? Write an INSERT statement to demonstrate
 what would happen if a new Supreme pizza with all the toppings was added to the Pizza Runner menu? */
 
INSERT INTO pizza_names VALUES(3, 'Supreme');
INSERT INTO pizza_recipes VALUES(3, (SELECT GROUP_CONCAT(topping_id SEPARATOR ', ') FROM pizza_toppings));
SELECT * 
FROM pizza_names
INNER JOIN pizza_recipes USING(pizza_id);




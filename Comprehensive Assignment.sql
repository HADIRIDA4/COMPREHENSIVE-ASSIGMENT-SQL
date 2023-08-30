--NOTE THE USAGE OF INFO AND DETAILS AS ALIASES
-- _INFO:TO THE TABLE THAT HAVE CHARACTERISTIC OF DIMENSION TABLE WICH IS DESCRIBING ENTITY SUCH AS CUSTOMER-FILM-TABLES
-- _DETAILS:TO THE TABLE THAT HAVE CHARACTERISTIC OF FACT TABLE WICH IS DESCRIBING ACTION OR TRANSACTION  SUCH AS RENTAL_PAYMENT
-- PART_1-SCALAR USAGE OF SOME SCALAR FUNCTION
--1.1
-- Convert all film titles in the film table to uppercase.
-- UPDATE FILM 
-- SET TITLE=UPPER(TITLE)
SELECT * FROM FILM;
-- CALCULATING  LENGTH OF EACH MOVIE IN HOUR (ROUND BY 2)
--1.2/1.3
SELECT 
    FILM_INFO.FILM_ID,
    FILM_INFO.TITLE,
    CAST(FILM_INFO.LENGTH / 60.0 AS DECIMAL(10, 2)) AS LENGTH_IN_HOURS,
	EXTRACT(YEAR FROM FILM_INFO.LAST_UPDATE) AS YEAR_UPDATED 
FROM FILM AS FILM_INFO
ORDER BY FILM_INFO.FILM_ID;
-- 2 AGGREGATE FUNCTIONS
--2.1
SELECT
	COUNT( FILM_ID) AS Number_of_Films,--Count the total number of films in the film table.
	ROUND(AVG(RENTAL_RATE),2) AS AVERAGE_RENTAL_RATE,--Calculate the average rental rate of films in the film table
	MAX(LENGTH) AS LONGEST_FILM_LENGTH,--Determine the highest  film lengths.
	MIN(LENGTH) AS SHORTEST_FILM_LENGTH--Determine the lowest film lengths.
FROM FILM AS FILM_INFO;
-- Find the total number of films in each film category.
SELECT 
    CATEGORY.NAME AS Category_Name,
    COUNT(FILM_CATEGORY.FILM_ID) AS Total_Films_in_Category
FROM 
    CATEGORY
INNER JOIN 
    FILM_CATEGORY ON CATEGORY.CATEGORY_ID = FILM_CATEGORY.CATEGORY_ID
GROUP BY 
    CATEGORY.NAME
ORDER BY 
    CATEGORY.NAME;

-- Window Functions
SELECT 
    FILM_INFO.FILM_ID,
    FILM_INFO.LENGTH,
    DENSE_RANK() OVER (ORDER BY FILM_INFO.LENGTH DESC) AS RANK
  FROM  FILM AS FILM_INFO;

-- USED DENSE_RANK TO BRIDGE THE GAP BETWEEN FILMS RANK DUE TO THE TIE OF SEVERAL MOVIES OF SAME LENGTH
-- Calculate the cumulative sum of film lengths in the film table using the SUM() window function.
SELECT 
    FILM_INFO.FILM_ID,
    FILM_INFO.LENGTH,
    SUM(FILM_INFO.LENGTH) OVER (ORDER BY FILM_INFO.FILM_ID) AS CUMULATIVE_SUM
FROM 
    FILM AS FILM_INFO;

--For each film in the film table, retrieve the title of the next film in terms of alphabetical order using the LEAD() function.
SELECT
    FILM_INFO.TITLE AS CURRENT_FILM,
    LEAD(FILM_INFO.title, 1, '') OVER (ORDER BY FILM_INFO.title) AS NEXT_FILM
FROM
    FILM AS FILM_INFO
ORDER BY
    FILM_INFO.TITLE;
--PART 4 CONDITIONAL FUNCTIONS
--4.1
SELECT
    FILM_INFO.TITLE AS Film_Title,
    FILM_INFO.LENGTH AS Film_Length,
    CASE
        WHEN FILM_INFO.LENGTH < 60 THEN 'Short'
        WHEN FILM_INFO.LENGTH BETWEEN 60 AND 120 THEN 'Medium'
        ELSE 'Long'
    END AS Film_Length_Category
FROM
    FILM AS FILM_INFO;
--4.2 
SELECT
   PAYMENT_DETAILS.PAYMENT_ID,
    PAYMENT_DETAILS.CUSTOMER_ID,
    COALESCE(AMOUNT, (SELECT AVG(amount) FROM payment)) AS corrected_amount
FROM
    PAYMENT AS PAYMENT_DETAILS;

--PART 5 UDF (USER DEFIND FUNCTIONS)
-- Create a UDF named film_category that accepts a film title as input and returns the category of the film.
--5.1
CREATE OR REPLACE FUNCTION film_category(film_title TEXT) RETURNS TEXT AS $$
DECLARE
  category TEXT;
BEGIN
  SELECT category_info.name INTO category
  FROM category AS category_info
  INNER JOIN film_category AS fc ON category_info.category_id = fc.category_id
  INNER JOIN film AS f ON f.film_id = fc.film_id
  WHERE f.title = film_title;

  RETURN category;
END;
$$ LANGUAGE plpgsql;


SELECT film_category('UPRISING UPTOWN');
-- 5.2 Develop a UDF named total_rentals that takes a film title as an argument and returns the total number of times the film has been rented
CREATE OR REPLACE FUNCTION total_rentals(film_title text)
RETURNS integer AS $$
DECLARE
    total_rental_count integer;
BEGIN
    SELECT COUNT(rental_details.rental_id) INTO total_rental_count
    FROM film AS film_info
    INNER JOIN inventory AS inventory_details ON film_info.film_id = inventory_details.film_id
    INNER JOIN rental AS rental_details ON rental_details.inventory_id = inventory_details.inventory_id
    WHERE film_info.title = film_title;

    RETURN total_rental_count;
END;
$$ LANGUAGE plpgsql;
SELECT  total_rentals('ACADEMY DINOSAUR');
-- 5.3
CREATE OR REPLACE FUNCTION customer_stats(CUSTOMER_IDD INTEGER) RETURNS JSON AS
$$
DECLARE -- Declare a variable for the customers'name,total_amount and number of rentals
  rentals_count NUMERIC;
  total_amount_spent NUMERIC;
  customer_name TEXT; 
BEGIN
  -- Get the customer's total rentals, total amount spent, and customer name.
  SELECT 
    COUNT(RENTAL_DETAILS.RENTAL_ID),
    SUM(PAYMENT_DETAILS.amount),
    CONCAT(CUSTOMER_INFO.FIRST_NAME ,' ',CUSTOMER_INFO.LAST_NAME) AS FULL_NAME -- Fetch customer name.
  INTO 
    rentals_count,
    total_amount_spent,
    customer_name
  FROM rental AS RENTAL_DETAILS
  INNER JOIN payment AS PAYMENT_DETAILS ON PAYMENT_DETAILS.customer_id = RENTAL_DETAILS.customer_id
  INNER JOIN customer AS CUSTOMER_INFO ON CUSTOMER_INFO.customer_id = RENTAL_DETAILS.customer_id -- Join with the customer table.
  WHERE RENTAL_DETAILS.customer_id = CUSTOMER_IDD
   GROUP BY CONCAT(CUSTOMER_INFO.FIRST_NAME ,' ',CUSTOMER_INFO.LAST_NAME);
  -- Return the customer's stats including the name in JSON format.
  RETURN json_build_object(
    'customer_name', customer_name,
    'rentals', rentals_count,
    'amount_spent', total_amount_spent
  );
END;
$$ LANGUAGE plpgsql;


SELECT customer_stats(1);


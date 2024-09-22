-- Part B -- 
-- SQL Transformation function --
CREATE OR REPLACE FUNCTION extract_month_year(rental_date TIMESTAMP)
RETURNS VARCHAR AS $$
BEGIN
    RETURN TO_CHAR(rental_date, 'YYYY-MM');
END;
$$ LANGUAGE plpgsql;

-- Usage in a query --
SELECT 
    extract_month_year(rental.rental_date) AS rental_month,
    SUM(payment.amount) AS total_revenue,
    COUNT(rental.rental_id) AS total_transactions
FROM 
    rental
JOIN 
    payment ON rental.rental_id = payment.rental_id
GROUP BY 
    rental_month
ORDER BY 
    rental_month;
-- End of Part B --

-- Drop Tables --
DROP TABLE detailed_rental_report;
DROP TABLE summary_rental_report;


-- Part C --
-- Create Detailed Table --
CREATE TABLE detailed_rental_report (
    rental_id INT,
    rental_date DATE, 
    return_date DATE,
    customer_id INT,
    customer_name VARCHAR(255),
    amount DECIMAL(10, 2)
);

-- Create Summary Table --
CREATE TABLE summary_rental_report (
    rental_month VARCHAR(7),  -- Format: YYYY-MM
    total_revenue DECIMAL(10, 2),
    total_transactions INT
);

-- Show Created Detailed and Summary Tables --
SELECT * FROM detailed_rental_report;
SELECT * FROM summary_rental_report;
-- End of Part C --


-- Part D --
-- SQL Query for Extracting Detailed Report Data --
INSERT INTO detailed_rental_report (rental_id, rental_date, return_date, customer_id, customer_name, amount)
SELECT 
    r.rental_id,
    r.rental_date,
    r.return_date,
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    p.amount
FROM 
    rental r
JOIN 
    payment p ON r.rental_id = p.rental_id
JOIN 
    customer c ON r.customer_id = c.customer_id
ORDER BY 
    r.rental_date;

-- Show populated Detailed and Summary Tables --
SELECT * FROM detailed_rental_report; -- 14596 total rows
SELECT * FROM summary_rental_report; -- 4 total rows
-- End of Part D --


-- Part E --
-- SQL Trigger to Update Summary Table --
CREATE OR REPLACE FUNCTION update_summary_report()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if the rental month already exists in the summary table --
    IF EXISTS (SELECT 1 FROM summary_rental_report WHERE rental_month = TO_CHAR(NEW.rental_date, 'YYYY-MM')) THEN
        -- If it exists, update the total revenue and total transactions for that month
        UPDATE summary_rental_report
        SET total_revenue = total_revenue + NEW.amount,
            total_transactions = total_transactions + 1
        WHERE rental_month = TO_CHAR(NEW.rental_date, 'YYYY-MM');
    ELSE
        -- If it doesn't exist, insert a new record for that month --
        INSERT INTO summary_rental_report (rental_month, total_revenue, total_transactions)
        VALUES (TO_CHAR(NEW.rental_date, 'YYYY-MM'), NEW.amount, 1);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create Trigger --
CREATE TRIGGER after_insert_detailed_report
AFTER INSERT ON detailed_rental_report
FOR EACH ROW
EXECUTE FUNCTION update_summary_report();

-- Add extra row to Detailed table --
INSERT INTO detailed_rental_report
VALUES ('1520', '2008-06-12', '2008-06-20', '341', 'Peter Menard', '10.99'); 
-- 1 row affected, now 14597 total rows

-- Verify Updated Detailed and Summary tables --
SELECT * FROM detailed_rental_report; -- 14597 total rows
SELECT * FROM summary_rental_report; -- 5 total rows
-- End of Part E --


-- Part F --
-- SQL Stored Procedure that refreshes the data in both the Detailed and Summary Tables --
CREATE OR REPLACE PROCEDURE refresh_rental_report()
LANGUAGE plpgsql
AS $$
BEGIN
    -- Temporarily disable the trigger --
    ALTER TABLE detailed_rental_report DISABLE TRIGGER after_insert_detailed_report;

    -- Clear the contents of the detailed table --
    TRUNCATE TABLE detailed_rental_report;

    -- Clear the contents of the summary table --
    TRUNCATE TABLE summary_rental_report;

    -- Insert fresh data into the detailed table --
    INSERT INTO detailed_rental_report (rental_id, rental_date, return_date, customer_id, customer_name, amount)
    SELECT 
        r.rental_id,
        r.rental_date,
        r.return_date,
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        p.amount
    FROM 
        rental r
    JOIN 
        payment p ON r.rental_id = p.rental_id
    JOIN 
        customer c ON r.customer_id = c.customer_id;

    -- Insert fresh data into the summary table by aggregating from the detailed table
    INSERT INTO summary_rental_report (rental_month, total_revenue, total_transactions)
    SELECT 
        TO_CHAR(d.rental_date, 'YYYY-MM') AS rental_month,
        SUM(d.amount) AS total_revenue,
        COUNT(d.rental_id) AS total_transactions
    FROM 
        detailed_rental_report d
    GROUP BY 
        rental_month
    ORDER BY 
        rental_month;

    -- Re-enable the trigger --
    ALTER TABLE detailed_rental_report ENABLE TRIGGER after_insert_detailed_report;

    RAISE NOTICE 'Rental report data refreshed successfully.';
END;
$$;

CALL refresh_rental_report();

-- Verify refreshed data --
SELECT * FROM detailed_rental_report; -- Refreshed to 14596 total rows
SELECT * FROM summary_rental_report; -- Refreshed to 4 total rows
-- End of Part F --

-- Drop Tables --
DROP TABLE detailed_rental_report;
DROP TABLE summary_rental_report;
-- End of SQL code --

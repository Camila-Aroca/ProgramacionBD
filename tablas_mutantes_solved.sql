CREATE OR REPLACE TRIGGER customers_credit_policy_trg 
    AFTER INSERT OR UPDATE 
    ON customers
    FOR EACH ROW 
DECLARE 
    l_max_credit   customers.credit_limit%TYPE; 
BEGIN 
    -- get the lowest non-zero credit 
    SELECT MIN (credit_limit) * 5 
        INTO l_max_credit 
        FROM customers
        WHERE credit_limit > 0;
    
    -- check with the new credit
    IF l_max_credit < :NEW.credit_limit 
    THEN 
        UPDATE customers 
        SET credit_limit = l_max_credit 
        WHERE customer_id = :NEW.customer_id; 
    END IF; 
END;
/

--UPDATE QUE GENERA EL ERROR DE TABLA MUTANTE
UPDATE customers
SET credit_limit = 12000
WHERE customer_id = 1;
/
--SOLUCIÓN CON TRIGGER COMPUESTO/COMPOUND TRIGGER
CREATE OR REPLACE TRIGGER customers_credit_policy_trg    
    FOR UPDATE OR INSERT ON customers    
    COMPOUND TRIGGER     
    TYPE r_customers_type IS RECORD (    
        customer_id   customers.customer_id%TYPE, 
        credit_limit  customers.credit_limit%TYPE    
    );    

    TYPE t_customers_type IS TABLE OF r_customers_type  
        INDEX BY PLS_INTEGER;    

    t_customer   t_customers_type;    

    AFTER EACH ROW IS    
    BEGIN  
        t_customer (t_customer.COUNT + 1).customer_id :=    
            :NEW.customer_id;    
        t_customer (t_customer.COUNT).credit_limit := :NEW.credit_limit;
    END AFTER EACH ROW;    

    AFTER STATEMENT IS    
        l_max_credit   customers.credit_limit%TYPE;    
    BEGIN      
        SELECT MIN (credit_limit) * 5    
            INTO l_max_credit    
            FROM customers
            WHERE credit_limit > 0;

        FOR indx IN 1 .. t_customer.COUNT    
        LOOP                                      
            IF l_max_credit < t_customer (indx).credit_limit    
            THEN    
                UPDATE customers    
                SET credit_limit = l_max_credit    
                WHERE customer_id = t_customer (indx).customer_id;    
            END IF;    
        END LOOP;    
    END AFTER STATEMENT;    
END; 


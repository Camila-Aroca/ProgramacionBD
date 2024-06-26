-- DEMO DE DISPARADORES O TRIGGERS
-- PROCEDIMIENTO MAS POTENTE DEL LENGUAJE DE PROGRAMACION DE LA BASE DE DATOS
-- SE PUEDE USAR PARA IMPLEMENTAR PRACTICAMENTE TODO: LO IMAGINABLE Y LO NO IMAGINABLE

--SINTAXIS DE UN TRIGGER
/*
CREATE OR REPLACE TRIGGER TR_NOMBRETRIGGER
CLAUSULA_DE_TIEMPO EVENTO OR EVENTO ON NOMBRETABLA
REFERENCING OLD AS NOMBRE | NEW AS NOMBRE
FOR EACH ROW
WHEN (CONDICION)
DECLARE
BEGIN
END;

CLAUSULA_DE_TIEMPO = BEFORE | AFTER | INSTEAD OF
EVENTO = INSERT | UPDATE | DELETE
ON NOMBRE_TABLA = TABLA ASOCIADA AL TRIGGER
REFERENCING = ASIGNA UN NUEVO NOMBRE A LAS PSEUDOCOLUMNAS 
              OLD Y NEW
              :NEW DA ACCESO A LOS VALORES DE LA SENTENCIA
              :NEW.EMPLOYEE_ID
              :OLD DA ACCESO A LOS VALORES ALMACENADOS EN LA TABLA
              :OLD.EMPLOYEE_ID
WHEN (CONDICION) = EL TRIGGER SE EJECUTA SOLO PARA LAS FILAS
              QUE CUMPLEN LA CONDICION
*/

DROP TABLE recuento_empleados;
CREATE TABLE recuento_empleados (
    total_empleados NUMBER NOT NULL 
);    
INSERT INTO recuento_empleados values (0); 
select * from recuento_empleados;

-- triggers a nivel de sentencia
-- trigger que actualiza el recuento de empleados
-- cada vez que se inserta un empleado
CREATE OR REPLACE TRIGGER tr_recuentoempleados
AFTER INSERT OR DELETE ON employees
DECLARE
BEGIN
   UPDATE recuento_empleados
     SET total_empleados = (SELECT COUNT(*) FROM EMPLOYEES);
END tr_recuentoempleados;
/

-- testing para el trigger
INSERT INTO EMPLOYEES
VALUES (EMPLOYEES_SEQ.NEXTVAL, 'GUERRA', 'PAZ',
        'PGUERRA', '987655672', '01022000',
        'IT_PROG', 10000, NULL, 120, 50);
        
INSERT INTO employees 
VALUES (employees_seq.nextval, 'Costa', 'Enrique', 'ECOSTA',
    '56735233', SYSDATE, 'SA_REP', 8500, .14, 145, 80);

INSERT INTO employees 
VALUES (employees_seq.nextval, 'Keller', 'Marcos', 'EKELLER',
    '56735233', SYSDATE, 'SA_REP', 8500, .14, 145, 80);        
SELECT * FROM EMPLOYEES;
DELETE FROM EMPLOYEES WHERE EMPLOYEE_ID = 209;

-- por politicas de la empresa solo es posible modificar
-- el sueldo de los empleados en los meses de enero y agosto 
-- de cada año. Elabore un trigger que impida la actualizacion
-- del sueldo en alguno de los meses indicados
CREATE OR REPLACE TRIGGER tr_anula_transaccion
BEFORE UPDATE ON EMPLOYEES
DECLARE
BEGIN
   IF EXTRACT(MONTH FROM SYSDATE) NOT IN (1,8) THEN
      RAISE_APPLICATION_ERROR(-20000, 
        'NO SE PERMITE MODIFICAR EL SUELDO EN ESTE PERIODO');
   END IF; 
END tr_anula_transaccion;
/

-- TESTING PARA EL TRIGGER
SELECT EMPLOYEE_ID, SALARY FROM EMPLOYEES;
UPDATE EMPLOYEES SET SALARY = 12000 WHERE EMPLOYEE_ID = 207;


-- TRIGGER QUE AUDITA LAS ACCIONES DML DE LOS USUARIOS
-- EN LA TABLA EMPLOYEES USO DE LOS PREDICADOS BOOLEANOS
-- CREAREMOS ESTA TABLA
DROP TABLE AUDITA_EMPLOYEES;
CREATE TABLE AUDITA_EMPLOYEES (
  FECHA TIMESTAMP,
  USUARIO VARCHAR2(30),
  ACCION CHAR
);

CREATE OR REPLACE TRIGGER tr_sapoman1
AFTER INSERT OR DELETE OR UPDATE ON EMPLOYEES
DECLARE
   v_accion CHAR(1);
BEGIN
  IF INSERTING THEN
     v_accion := 'I';     
  ELSIF DELETING THEN
     v_accion := 'D';     
  ELSE
     v_accion := 'U';     
  END IF;
  INSERT INTO audita_employees
  VALUES (SYSTIMESTAMP, USER, V_ACCION);
END tr_sapoman1;
/

-- TESTING PARA EL TRIGGER
INSERT INTO employees 
VALUES (employees_seq.nextval, 'Costa', 'Enrique', 'ECOSTA',
    '56735233', SYSDATE, 'SA_REP', 8500, .14, 145, 80);

INSERT INTO employees 
VALUES (employees_seq.nextval, 'Keller', 'Marcos', 'EKELLER',
    '56735233', SYSDATE, 'SA_REP', 8500, .14, 145, 80);

ALTER TRIGGER TR_ANULA_TRANSACCION DISABLE;

UPDATE employees
SET salary = 9300
WHERE email = 'ECOSTA';

DELETE 
FROM EMPLOYEES 
WHERE EMAIL = 'ECOSTA';

SELECT * FROM audita_employees;

-- TRIGGERS A NIVEL DE FILA
-- TRIGGER QUE AUDITA LAS ACCIONES DML EN LA TABLA EMPLOYEES
-- USO DE LOS PREDICADOS BOOLEANOS 
-- Y DE LAS PSEUDOCOLUMNAS NEW Y OLD

DROP TABLE audit_changes; 
CREATE TABLE audit_changes (
   fecha TIMESTAMP,
   usuario VARCHAR2(30),
   accion CHAR,
   cambio_efectuado VARCHAR2(300)
);

CREATE OR REPLACE TRIGGER tr_sapoman_v2
AFTER INSERT OR UPDATE OF SALARY,COMMISSION_PCT OR DELETE ON EMPLOYEES
FOR EACH ROW
DECLARE
  V_ACCION CHAR(1);
  v_msg VARCHAR2(300);
BEGIN
   IF INSERTING THEN
      v_accion := 'I';
      v_msg := 'Se contrató al empleado ' || :NEW.FIRST_NAME || ' ' || :NEW.LAST_NAME
                || ' CON LA ID ' || :NEW.EMPLOYEE_ID;
   ELSIF UPDATING('salary') THEN
       v_accion := 'U';
       v_msg := 'Se modificó el sueldo del empleado ' || :NEW.first_name || ' ' || :OLD.LAST_NAME 
                 || 'Sueldo antiguo: ' || :OLD.SALARY || ' Nuevo sueldo ' || :NEW.salary;
   ELSIF UPDATING('commission_pct') THEN
       v_accion := 'U';
       v_msg := 'Se modificó el sueldo del empleado ' || :NEW.first_name || ' ' || :OLD.LAST_NAME 
                 || 'Sueldo antiguo: ' || :OLD.SALARY || ' Nuevo sueldo ' || :NEW.salary;
   ELSE
      v_accion := 'D';
      v_msg := 'Se eliminó el empleado ' || :OLD.FIRST_NAME 
                || ' ' || :OLD.LAST_NAME
                || ' CON LA ID ' || :OLD.EMPLOYEE_ID;      
   END IF;
   INSERT INTO AUDIT_CHANGES
   VALUES (SYSDATE, USER, v_accion, v_msg);
END tr_sapoman_v2;
/

-- TESTING PARA EL TRIGGER
INSERT INTO employees 
VALUES (employees_seq.nextval, 'Costa', 'Enrique', 'ECOSTA',
    '56735233', SYSDATE, 'SA_REP', 8500, .14, 145, 80);

UPDATE employees
SET salary = 9300
WHERE email = 'ECOSTA';

DELETE 
FROM EMPLOYEES 
WHERE EMAIL = 'ECOSTA';

SELECT * FROM AUDIT_CHANGES;

-- TRIGGER QUE MODIFICA LA TABLA SUPERVISOR 
-- SI SE AGREGA UN EMPLEADO AL SUPERVISOR SE DEBE SUMAR 1 AL CAMPO EMPLEADOS
-- Y U$150 AL CAMPO BONIFICACION.  SE DEBE PROCEDER AL REVES SI SE BORRA UN EMPLEADO
-- SUPERVISADO. SI SE MODIFICA EL SUPERVISOR DE UN EMPLEADO SE DEBE QUITAR 1 Y 150
-- DE QUIEN LO PIERDE Y AGREGARSELO A QUIEN LO ASUME

DROP TABLE supervisor;
CREATE TABLE supervisor AS
SELECT manager_id, count(*) empleados, count(*) * 150 bonificacion
FROM employees
WHERE manager_id IS NOT NULL
GROUP BY manager_id;

SELECT * FROM SUPERVISOR;

CREATE OR REPLACE TRIGGER TR_supervisor
BEFORE INSERT OR UPDATE OR DELETE ON EMPLOYEES
FOR EACH ROW
DECLARE
BEGIN
   IF INSERTING THEN
      UPDATE SUPERVISOR
        SET empleados = empleados + 1,
            bonificacion = bonificacion + 150
      WHERE manager_id = :NEW.manager_id;      
   ELSIF DELETING THEN
      UPDATE SUPERVISOR
        SET empleados = empleados - 1,
            bonificacion = bonificacion - 150
      WHERE manager_id = :OLD.manager_id;      
   ELSE
      UPDATE SUPERVISOR
        SET empleados = empleados + 1,
            bonificacion = bonificacion + 150
      WHERE manager_id = :NEW.manager_id;      
      UPDATE SUPERVISOR
        SET empleados = empleados - 1,
            bonificacion = bonificacion - 150
      WHERE manager_id = :OLD.manager_id;      
   END IF;
END TR_supervisor;
/

-- testing
SELECT * FROM SUPERVISOR WHERE manager_id in (101,102);

INSERT INTO employees 
VALUES (employees_seq.NEXTVAL, 'Costa', 'Enrique', 'ECOSTA',
    '56735233', SYSDATE, 'SA_REP', 8500, .14, 101, 80);
    
DELETE FROM employees WHERE email = 'ECOSTA';

UPDATE EMPLOYEES SET MANAGER_ID = 102 WHERE EMAIL = 'ECOSTA';

SELECT * FROM SUPERVISOR WHERE manager_id in (101,102);

-- LOS EMPLEADOS GANAN UNA ASIGNACION ESPECIAL SIEMPRE QUE 
-- SEAN DEL DEPARTAMENTO 80.  CUANDO SE INSERTE UNA ASIGNACION 
-- EN LA TABLA HONORARIOS, 
-- SE DEBE AGREGAR AL SUELDO EL MONTO DE ESA ASIGNACION. 
-- CUANDO SE ELIMINE LA ASIGNACION SE DEBE QUITAR DEL SUELDO EL MONTO DE 
-- LA ASIGNACION, SI LA ASIGNACION SE MODIFICA SE DEBE RESTAR O 
-- SUMAR AL SUELDO LA DIFERENCIA ENTRE LA NUEVA Y LA VIEJA ASIGNACION

DROP TABLE honorarios;
CREATE TABLE HONORARIOS AS
SELECT EMPLOYEE_ID, department_id,  salary asignacion 
FROM employees WHERE 1 = 2;
ALTER TABLE HONORARIOS ADD CONSTRAINT PK_HONORARIOS PRIMARY KEY (EMPLOYEE_ID);

CREATE OR REPLACE TRIGGER TR_ASIGNACION
BEFORE INSERT OR DELETE OR UPDATE ON HONORARIOS
FOR EACH ROW
WHEN (NEW.DEPARTMENT_ID = 80 OR OLD.DEPARTMENT_ID = 80)
DECLARE
BEGIN
   IF INSERTING THEN
      UPDATE employees
        SET salary = salary + :NEW.asignacion
      WHERE employee_id = :NEW.employee_id;  
   ELSIF DELETING THEN
      UPDATE employees
        SET salary = salary - :OLD.asignacion
      WHERE employee_id = :old.employee_id;  
   ELSE
      UPDATE employees
        SET salary = salary + (:NEW.asignacion - :OLD.asignacion)
      WHERE employee_id = :NEW.EMPLOYEE_ID;  
   END IF;
END TR_ASIGNACION;
/

-- TESTING DEL TRIGGER
-- vemos el sueldo que tienen estos empleados
SELECT employee_id, department_id, salary 
FROM employees WHERE employee_id IN (146,120);

-- testing 
-- ingresamos asignacion para el empleado con id 146 luego volvemos a verificar
INSERT INTO HONORARIOS
VALUES (146, 80, 300);
SELECT employee_id, department_id, salary 
FROM employees WHERE employee_id IN (146,120);
rollback;

INSERT INTO HONORARIOS
VALUES (120, 50, 1000);
SELECT employee_id, department_id, salary 
FROM employees WHERE employee_id IN (146,120);

-- actualizamos y verificamos
UPDATE HONORARIOS 
  SET asignacion = 100
WHERE EMPLOYEE_ID = 146;

SELECT employee_id, department_id, salary FROM employees WHERE employee_id IN (146,120);

UPDATE HONORARIOS 
  SET asignacion = 500
WHERE EMPLOYEE_ID = 146;

SELECT employee_id, department_id, salary 
FROM employees WHERE employee_id IN (146,120);

DELETE FROM HONORARIOS
WHERE EMPLOYEE_ID = 146;

SELECT employee_id, department_id, salary FROM employees WHERE employee_id IN (146,120);


CREATE TABLE historico_empleados AS
SELECT * FROM employees
WHERE 1 = 2;

-- trigger que respalda datos de empleados desvinculados
CREATE OR REPLACE TRIGGER tr_bkup_empleados
AFTER DELETE ON employees
REFERENCING NEW AS N OLD AS V
FOR EACH ROW
DECLARE
BEGIN
    INSERT INTO HISTORICO_EMPLEADOS
    VALUES (:V.EMPLOYEE_ID, :V.FIRST_NAME, :V.LAST_NAME, :V.EMAIL,
            :V.PHONE_NUMBER, :V.HIRE_DATE, :V.JOB_ID, :V.SALARY,
            :V.COMMISSION_PCT, :V.MANAGER_ID, :V.DEPARTMENT_ID);
END tr_bkup_empleados;
/

-- TESTING
INSERT INTO employees 
VALUES (employees_seq.NEXTVAL, 'Costa', 'Enrique', 'ECOSTA',
    '56735233', SYSDATE, 'SA_REP', 8500, .14, 101, 80);
    
DELETE FROM employees WHERE email = 'ECOSTA';

-- IMPLEMENTACION DE RESTRICCIONES COMPLEJAS
-- NINGUN EMPLEADO PUEDE GANAR UN SUELDO SUPERIOR AL DE SU JEFE 
SELECT DISTINCT E.SALARY
FROM EMPLOYEES M JOIN EMPLOYEES E
ON M.MANAGER_ID = E.EMPLOYEE_ID
WHERE M.MANAGER_ID = 121;

CREATE OR REPLACE TRIGGER TR_SUELDO_SUPERVISOR
BEFORE INSERT OR UPDATE ON EMPLOYEES
FOR EACH ROW
DECLARE
    v_sueldo_man NUMBER;
BEGIN
    SELECT DISTINCT E.SALARY
    INTO v_sueldo_man
    FROM EMPLOYEES M JOIN EMPLOYEES E
    ON M.MANAGER_ID = E.EMPLOYEE_ID
    WHERE M.MANAGER_ID = :NEW.MANAGER_ID;
    IF :NEW.SALARY > v_sueldo_man THEN
        RAISE_APPLICATION_ERROR(-20002,
         'EL SUELDO DEL EMPLEADO NO PUEDE SUPERAR AL DE SU SUPERVISOR');
    END IF;
END TR_SUELDO_SUPERVISOR;
/

-- TESTING
INSERT INTO employees 
VALUES (employees_seq.nextval, 'Costa', 'Enrique', 'ECOSTA',
    '56735233', SYSDATE, 'SA_REP', 8500, .14, 121, 50);

UPDATE EMPLOYEES
  SET SALARY = 8500
  WHERE EMPLOYEE_ID = 199;


-- UN SEUPERVISOR NO PUEDE TENER MAS DE 8 EMPLEADOS A CARGO
DROP TABLE supervisor; 
CREATE TABLE supervisor AS
SELECT manager_id, COUNT(*) numempleados, count(*) * 150 bonificaciones
FROM employees
WHERE manager_id IS NOT NULL
GROUP BY manager_id;

ALTER TABLE supervisor 
 ADD CONSTRAINT pk_supervisor PRIMARY KEY (manager_id);

ALTER TABLE supervisor
 ADD CONSTRAINT fk_supervisor_empleado FOREIGN KEY (manager_id)
 REFERENCES employees (employee_id);
 
-- TESTING
SELECT * FROM supervisor;

-- ingresamos un empleado con manager 120 que ya tiene 8 
-- empleados a cargo
INSERT INTO employees 
VALUES (employees_seq.nextval, 'Costa', 'Enrique', 'ECOSTA',
    '56735233', SYSDATE, 'SA_REP', 8500, .14, 120, 50);

-- intentamos cambiar a 120 el manager del empleado con id 184
UPDATE employees
  SET manager_id = 120
WHERE employee_id = 184;

-- EJEMPLO DE TRIGGER INSTEAD OF
-- CREAREMOS UNA VISTA
CREATE OR REPLACE VIEW v_empdetalles AS 
  SELECT e.employee_id, e.first_name, e.last_name, e.email, e.phone_number,
         e.hire_date, e.job_id, e.salary * 1.20 aumentado, 
         e.commission_pct, e.manager_id, e.department_id
  FROM employees e
  WHERE salary * 1.2 > 9000;
  
SELECT * FROM V_EMPDETALLES;

-- este registro se inserta normalmente
INSERT INTO employees 
VALUES (employees_seq.nextval, 'Enrique', 'Costa', 'ECOSTA',
    '56735233', SYSDATE, 'SA_REP', 8500, .14, 114, 50);

-- no es posible insertar a traves de la vista  
INSERT INTO V_EMPDETALLES
VALUES (EMPLOYEES_SEQ.NEXTVAL, 'Karen', 'Comodo', 'KCOMODO', '83292334', SYSDATE, 
        'IT_PROG', 8000, NULL, 103, 60);

-- el empleado con email ECOSTA existe, pero no se admite la 
-- modificacion de su salario a través de la vista
UPDATE v_empdetalles
  SET aumentado = 9000
WHERE email = 'ECOSTA';

-- el empleado con email ECOSTA existe, y su eliminación está admitida
DELETE FROM V_empdetalles
WHERE email = 'ECOSTA';

CREATE OR REPLACE TRIGGER tr_en_lugar_de
INSTEAD OF INSERT OR DELETE OR UPDATE ON v_empdetalles
FOR EACH ROW
BEGIN
  IF inserting THEN
     INSERT INTO employees 
      VALUES (:NEW.employee_id, :NEW.first_name, :NEW.last_name, :NEW.email, 
              :NEW.phone_number, :NEW.hire_date, :NEW.job_id, :NEW.aumentado,
              :NEW.commission_pct, :NEW.manager_id, :NEW.department_id);
  ELSIF updating THEN
     UPDATE employees
        SET salary = :NEW.aumentado
     WHERE employee_id = :NEW.employee_id;   
  ELSE
      DELETE FROM employees
      WHERE employee_id = :OLD.employee_id;
  END IF;
END;
/

-- ahora esta fila se inserta a traves de la vista  
INSERT INTO V_EMPDETALLES
VALUES (EMPLOYEES_SEQ.NEXTVAL, 'Karen', 'Comodo', 'KCOMODO', '83292334', SYSDATE, 
        'IT_PROG', 8000, NULL, 103, 60);

-- el sueldo de este empleado puede ser modificado
UPDATE v_empdetalles
  SET aumentado = 9000
WHERE email = 'KCOMODO';

-- la eliminación sigue admitida
DELETE FROM v_empdetalles
WHERE email = 'KCOMODO';




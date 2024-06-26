--Las asignaciones de colación y movilización son montos fijos de $75.000 y $60.000 respectivamente.
/*
Se paga una asignación especial por los años que el empleado lleva trabajando en la empresa. 
Esta asignación corresponde a un porcentaje del monto total de las ventas del empleado en el mes y año de proceso. 
Este porcentaje se encuentra en la tabla PORCENTAJE_ANTIGUEDAD.
*/

/*
Se paga una comisión por las ventas que el empleado realizó en el mes y año de proceso. Esta comisión corresponde 
a un porcentaje del monto total de las ventas del empleado. El porcentaje se encuentra en la tabla 
PORCENTAJE_COMISION_VENTA.
*/

/*
Se paga una asignación asociada con la escolaridad que posee el empleado. 
Esta asignación corresponde a un porcentaje del sueldo base del empleado. 
El porcentaje se encuentra en la tabla PORCENTAJE_ESCOLARIDAD:
*/

--TOTAL HABERES: sueldo base del empleado + colación + movilización + asignación por años trabajados + 
--comisión por ventas + asignación por escolaridad.

/*
REQUERIMIENTOS
----------------PACKAGE----------------------: 
**Procedimiento de error: Un procedimiento para insertar los errores que se produzcan al obtener los porcentajes para calcular la
asignación especial por antigüedad y la asignación por escolaridad. La información se debe insertar en la tabla 
ERROR_CALC indicando el subprograma en el que se produjo el error y el mensaje de error Oracle, según se muestra 
en el ejemplo. Para la columna CORREL_ERROR usar el objeto secuencia SEQ_ERROR

**Una función que retorne el monto total de las ventas realizadas por el empleado en el mes y año que se está 
procesando. Si el empleado no posee ventas en el mes y año de proceso, la función debe retornar cero.

**Una variable que pueda ser usada por el procedimiento almacenado principal para recuperar el monto 
de las ventas calculado con la función anterior.

*/

-------SEGUNDO-----------
CREATE OR REPLACE PACKAGE pkg_ventas AS
    PROCEDURE sp_salvame (p_iderror NUMBER, p_nomsubp VARCHAR2, p_msg VARCHAR2);
    FUNCTION fn_ventas (p_runemp VARCHAR2, p_fecha VARCHAR2) RETURN NUMBER;
    vp_ventas_mes NUMBER; 
END pkg_ventas;

/

CREATE OR REPLACE PACKAGE BODY pkg_ventas AS
    PROCEDURE sp_salvame (
    p_iderror NUMBER, p_nomsubp VARCHAR2, p_msg VARCHAR2
    )
    AS 
       v_sql VARCHAR2(300); 
    BEGIN
        v_sql := 'INSERT INTO error_calc
                    VALUES (:1, :2, :3)';
        EXECUTE IMMEDIATE v_sql USING p_iderror, p_nomsubp, p_msg;
    END sp_salvame;
    
    
    FUNCTION fn_ventas (
    p_runemp VARCHAR2, p_fecha VARCHAR2
    ) RETURN NUMBER
    
    AS
        v_sql VARCHAR2(300);
    BEGIN
        v_sql := 'SELECT NVL(SUM(monto_total_boleta),0)
                  FROM boleta
                  WHERE run_empleado = :1 AND 
                  TO_CHAR(fecha, ''MMYYYY'') = :2';
        EXECUTE IMMEDIATE v_sql INTO pkg_ventas.vp_ventas_mes USING p_runemp, p_fecha;
    END;    
END pkg_ventas;

/


/*

---------FUNCIONES ALMACENADAS-----------------

--FN_PCT_ANTI
Una función almacenada que retorne el porcentaje por antigüedad que le corresponde al 
empleado según los años que lleva trabajando en la empresa. El porcentaje se encuentra en la tabla 
PORCENTAJE_ANTIGUEDAD. Esta función se deberá usar en el procedimiento almacenado principal para calcular 
la asignación especial por antigüedad.
Esta función además deberá controlar cualquier error que se produzca, para ello deberá ejecutar el
procedimiento del Package que graba los errores. Al producirse un error la función debe retornar cero.

*/

CREATE OR REPLACE FUNCTION fn_pct_anti (
    p_runemp VARCHAR2
) RETURN NUMBER
AS
    v_anti NUMBER;
    v_pct_anti NUMBER;
    v_sql VARCHAR2(300);
    v_msg VARCHAR2(300);
BEGIN
    --CALCULO ANTIGUEDAD---
    SELECT TRUNC(MONTHS_BETWEEN(SYSDATE, fecha_contrato)/12)
    INTO v_anti
    FROM empleado
    WHERE run_empleado = p_runemp;
    
    
    ---CALCULO PCT----
        BEGIN
            select porc_antiguedad/100
            into v_pct_anti
            from porcentaje_antiguedad
            where v_anti between ANNOS_ANTIGUEDAD_INF and ANNOS_ANTIGUEDAD_sup;
        EXCEPTION
        WHEN OTHERS THEN 
             v_msg := SQLERRM;
             v_pct_anti := 0;
             pkg_ventas.sp_salvame(seq_error.nextval,'Error en la '|| $$PLSQL_UNIT ||' al obtener el % asociado
             a '||v_anti||' anios de antiguedad.', v_msg);
        END;
    RETURN v_pct_anti;    
END;
/


CREATE OR REPLACE FUNCTION fn_pct_esc (
    p_codesc NUMBER
) RETURN NUMBER
AS
    v_pct_esc NUMBER;
    v_sql VARCHAR2(300);
    v_msg VARCHAR2(300);
BEGIN
    BEGIN
      v_sql := 'select pe.porc_escolaridad/100
                from porcentaje_escolaridad pe JOIN empleado e
                ON pe.cod_escolaridad = e.cod_escolaridad
                where pe.cod_escolaridad = :1';
    execute immediate v_sql INTO v_pct_esc using p_codesc;
    EXCEPTION
    WHEN OTHERS THEN 
         v_pct_esc := 0;
         v_msg := SQLERRM;
         pkg_ventas.sp_salvame(seq_error.nextval, $$PLSQL_UNIT, v_msg);
    END;
    RETURN v_pct_esc;    
END fn_pct_esc;
/
/*
--FN_PCT_ESC
Una función almacenada que retorne el porcentaje por escolaridad que le corresponde al empleado según su 
escolaridad. El porcentaje se encuentra en la tabla PORCENTAJE_ESCOLARIDAD. Esta función se deberá
usar en el procedimiento almacenado principal para calcular la asignación por escolaridad.
Esta función además deberá controlar cualquier error que se produzca, para ello deberá ejecutar el 
procedimiento del Package que graba los errores. Al producirse un error la función debe retornar cero.

*/
/*
****************PRIMERO*****************
-------------PROC ALMACENADO------------
Un procedimiento almacenado principal para efectuar el cálculo de los haberes de las remuneraciones 
de los empleados de la empresa. Se deben procesar todos los empleados. 
Efectuar la prueba de su proceso para las remuneraciones del mes de junio de 2022.

El procedimiento debe integrar el uso de los constructores del Package y de las Funciones 
Almacenadas para construir la solución requerida.

El resultado del proceso debe quedar almacenado en la tabla DETALLE_HABERES_MENSUAL.

Los siguientes valores deberán ser ingresados como parámetros al procedimiento almacenado:
    o Fechadeproceso(añoymes)
    o Valoresdemovilizaciónycolación

*/
CREATE OR REPLACE PROCEDURE sp_haberes (
    p_fecha VARCHAR2, p_mov NUMBER, p_col NUMBER
)
AS
    
    CURSOR c_haberes IS
        SELECT 
        e.run_empleado, e.nombre ||' '||e.paterno||' '||e.materno nombre,
        e.fecha_contrato, e.sueldo_base, TO_CHAR(b.fecha, 'MMYYYY'), e.cod_escolaridad, 
        SUM(b.monto_total_boleta) ventas
        FROM empleado e 
        JOIN boleta b ON e.run_empleado = b.run_empleado
        WHERE TO_CHAR(b.fecha, 'MMYYYY') = p_fecha
        GROUP BY e.run_empleado, e.nombre, e.paterno, e.materno, e.fecha_contrato, e.sueldo_base, 
        TO_CHAR(b.fecha, 'MMYYYY'), e.cod_escolaridad;
        
--VARIABLES ESCALARES
    v_asig_anti NUMBER;
    v_asig_esc NUMBER;
    v_pct_ventas NUMBER;
    v_com_ventas NUMBER;
    v_total_haberes NUMBER;
    
BEGIN

    
    FOR r_haberes IN c_haberes LOOP
    
    v_asig_anti := ROUND(pkg_ventas.vp_ventas_mes * fn_pct_anti(r_haberes.run_empleado));
    v_asig_esc := ROUND(r_haberes.sueldo_base * fn_pct_esc(r_haberes.cod_escolaridad));
    
    SELECT NVL((porc_comision/100),0)
    INTO v_pct_ventas
    FROM porcentaje_comision_venta
    WHERE pkg_ventas.vp_ventas_mes BETWEEN venta_inf AND venta_sup;
    
    v_com_ventas := ROUND(pkg_ventas.vp_ventas_mes * v_pct_ventas);
                    
    v_total_haberes :=r_haberes.sueldo_base+p_col+p_mov+v_asig_anti+v_asig_esc+v_com_ventas;
                    
    DBMS_OUTPUT.PUT_LINE(SUBSTR(p_fecha, 1,2)
    ||' '||SUBSTR(p_fecha, 3,6)
    ||' '||r_haberes.run_empleado
    ||' '||r_haberes.nombre
    ||' '||r_haberes.sueldo_base
    ||' '||p_col
    ||' '||p_mov
    ||' '||v_asig_anti
    ||' '||v_asig_esc
    ||' '||v_com_ventas
    ||' '||v_total_haberes
    );
    
    INSERT INTO detalle_haberes_mensual VALUES (SUBSTR(p_fecha, 1,2)
    ,SUBSTR(p_fecha, 3,6)
    ,r_haberes.run_empleado
    ,r_haberes.nombre
    ,r_haberes.sueldo_base
    ,p_col
    ,p_mov
    ,v_asig_anti
    ,v_asig_esc
    ,v_com_ventas
    ,v_total_haberes);
    
    END LOOP;
    COMMIT;
END;

/



/*
----------TRIGGER---------------
Este trigger deberá generar la información de la tabla CALIFICACION_MENSUAL_EMPLEADO. 
Esto significa que cuando el Procedimento Almacenado genere la información de cada empleado en la tabla 
DETALLE_HABERES_MENSUAL, en forma simultánea el trigger deberá almacenar en la tabla CALIFICACION_MENSUAL_EMPLEADO: 
el mes de proceso, año de proceso, el run del empleado, el total de haberes y su calificación.
● El total de haberes corresponde a la sumatoria de las asignaciones especificadas en las reglas de negocio 
de la letra a la e.
● La calificación del empleado corresponde a lo especificado en la regla de negocio de la letra f.
*/

CREATE OR REPLACE TRIGGER tr_calificacion
AFTER INSERT ON detalle_haberes_mensual
FOR EACH ROW
BEGIN
    IF :NEW.total_haberes BETWEEN 400000 and 700000 THEN 
    INSERT INTO calificacion_mensual_empleado (MES, ANNO, RUN_EMPLEADO, TOTAL_HABERES, CALIFICACION)
    VALUES(:NEW.mes, :NEW.anno, :NEW.run_empleado, :NEW.total_haberes, 'Total de haberes '||:NEW.total_haberes||
    'Califica como empleado con salario bajo promedio.');
    
    ELSIF :NEW.total_haberes BETWEEN 700001 and 900000 THEN 
    INSERT INTO calificacion_mensual_empleado (MES, ANNO, RUN_EMPLEADO, TOTAL_HABERES, CALIFICACION)
    VALUES(:NEW.mes, :NEW.anno, :NEW.run_empleado, :NEW.total_haberes, 'Total de haberes '||:NEW.total_haberes||
    'Califica como empleado con salario promedio.');
    
    ELSIF :NEW.total_haberes > 900000 THEN 
    INSERT INTO calificacion_mensual_empleado (MES, ANNO, RUN_EMPLEADO, TOTAL_HABERES, CALIFICACION)
    VALUES(:NEW.mes, :NEW.anno, :NEW.run_empleado, :NEW.total_haberes, 'Total de haberes '||:NEW.total_haberes||
    'Califica como empleado con salario SOBRE promedio.');
    
    END IF;
END tr_calificacion;

/

--PROBANDO TRIGGERS
---CREAR UN TRIGGER QUE ELIMINE DE LA TABLA RECUENTO_empleados CUALQUIER EMPLEADO CON SUELDO 0
/*CREATE TABLE RECUENTO_EMPLEADOS (
    TOTAL_EMPLEADOS NUMBER
);*/

-- Inicializar la tabla con el recuento actual de empleados
/*INSERT INTO RECUENTO_EMPLEADOS (TOTAL_EMPLEADOS)
SELECT COUNT(*) FROM EMPLEADO;
COMMIT;
*/
select * from recuento_empleados;
/*
INSERT INTO EMPLEADO VALUES ('23456789-2', 'MARCELA', 'FERNANDEZ', 'PEREZ', 'CALLE 1234', 2, 912345678, 'MFERNANDEZ@GMAIL.COM', 0, TO_DATE('12-03-2010', 'DD-MM-YYYY'), 2, 3, 1, 3);
INSERT INTO EMPLEADO VALUES ('34567890-3', 'JUAN', 'GARCIA', 'LOPEZ', 'AVENIDA 5678', 3, 923456789, 'JGARCIA@GMAIL.COM', 0, TO_DATE('15-07-2015', 'DD-MM-YYYY'), 3, 4, 2, 4);
INSERT INTO EMPLEADO VALUES ('45678901-4', 'PATRICIA', 'HERRERA', 'GONZALEZ', 'CALLE FALSA 123', 4, 934567890, 'PHERRERA@GMAIL.COM', 0, TO_DATE('20-09-2018', 'DD-MM-YYYY'), 4, 5, 3, 5);
INSERT INTO EMPLEADO VALUES ('56789012-5', 'CARLOS', 'MARTINEZ', 'RAMIREZ', 'AVENIDA SIEMPRE VIVA 742', 5, 945678901, 'CMARTINEZ@GMAIL.COM', 0, TO_DATE('01-11-2020', 'DD-MM-YYYY'), 5, 1, 4, 1);
INSERT INTO EMPLEADO VALUES ('67890123-6', 'ANA', 'PEREIRA', 'SOTO', 'CALLE 4567', 6, 956789012, 'APEREIRA@GMAIL.COM', 0, TO_DATE('22-05-2012', 'DD-MM-YYYY'), 1, 2, 5, 2);

DELETE FROM EMPLEADO
WHERE SUELDO_BASE = 0;*/

CREATE OR REPLACE TRIGGER tr_actualiza_recuento
AFTER INSERT OR DELETE ON empleado
DECLARE
BEGIN 
    UPDATE recuento_empleados 
        SET total_empleados = (select count(*) from empleado);
END tr_actualiza_recuento;

/


-------------------------

BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE error_calc';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE detalle_haberes_mensual';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE calificacion_mensual_empleado';
    sp_haberes('062022', 60000, 75000);
    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_error';
    EXECUTE IMMEDIATE 'CREATE SEQUENCE seq_error';
END;







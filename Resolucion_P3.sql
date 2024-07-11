--REQUERIMIENTOS MINIMOS

--TRIGGER
--DROP trigger tr_asig;
CREATE OR REPLACE TRIGGER tr_asig
BEFORE INSERT ON det_asigna_mes
FOR EACH ROW
DECLARE 
BEGIN    
    UPDATE totalasigna_mes
        SET total_asignaciones = total_asignaciones + :NEW.total_asignaciones
    WHERE runvendedor = :NEW.run_vendedor;
END tr_asig;
/



/*
--1. PACKAGE QUE CONTENGA:

-procedimiento para insertar errores producidos al ejecutar cualquiera de los subprogramas. 
info se debe insertar en tabla ERRASIGNA indicando subprograma en que se produjo el error y el mensaje de 
error de Oracle.
-Funcion que retorna MONTO de la asignacion por cada orden atendida en el mes procesado
-Variable publica que pueda ser usada por el procedimiento almacenado principal para recuperar el
monto de la asignación calculado con la función anterior.

*/

CREATE OR REPLACE PACKAGE pkg_asig AS
    PROCEDURE sp_salvame (p_iderror NUMBER, p_nomsubp VARCHAR2, p_msg VARCHAR2);
    FUNCTION fn_asig (p_fecha VARCHAR2, p_numvendedor NUMBER, p_id_orden NUMBER) RETURN NUMBER;
    vp_asig NUMBER;
END pkg_asig;
/

CREATE OR REPLACE PACKAGE BODY pkg_asig AS
    PROCEDURE sp_salvame (
        p_iderror NUMBER, p_nomsubp VARCHAR2, p_msg VARCHAR2
    )
    AS 
        v_sql VARCHAR2(300); 
    BEGIN
        v_sql := 'INSERT INTO errasigna VALUES (:1, :2, :3)';
        EXECUTE IMMEDIATE v_sql USING p_iderror, p_nomsubp, p_msg;
    END sp_salvame;
    
    FUNCTION fn_asig (
        p_fecha VARCHAR2,
        p_numvendedor NUMBER,
        p_id_orden NUMBER
    ) RETURN NUMBER
    AS 
        v_subtotal NUMBER;
        v_msg VARCHAR2(300);
        v_pct_asig NUMBER;
        v_asig NUMBER;
    BEGIN
        BEGIN
            SELECT NVL(subtotal, 0) 
            INTO v_subtotal
            FROM orden
            WHERE TO_CHAR(fec_orden, 'MMYYYY') = p_fecha
            AND numvendedor = p_numvendedor
            AND id_orden = p_id_orden;
        EXCEPTION
            WHEN OTHERS THEN 
                v_msg := SQLERRM;
                v_subtotal := 0;
                pkg_asig.sp_salvame(seq_error.nextval, $$PLSQL_UNIT, v_msg);   
        END;        
            BEGIN 
            SELECT pct_asi
            INTO v_pct_asig
            FROM porcentaje_asignacion_orden
            WHERE v_subtotal BETWEEN venta_inf AND venta_sup;
            
        EXCEPTION
            WHEN OTHERS THEN 
                v_msg := SQLERRM;
                v_pct_asig := 0;
                pkg_asig.sp_salvame(seq_error.nextval, $$PLSQL_UNIT, v_msg);   
        END;
        
        pkg_asig.vp_asig := ROUND(v_pct_asig * v_subtotal);
                
        RETURN pkg_asig.vp_asig;       
    END fn_asig;
        
END pkg_asig;
/


/*
--2. FUNCIONES ALMACENADAS
--Una que retorna el % que le corresponde al vendedor según su status. Se debe usar en el procedimiento 
almacenado principal para calcular comisión por ventas. Debe ejecutar el procedimiento de error y en ese caso
retornar 3%.

*/

CREATE OR REPLACE FUNCTION fn_pct_com (
    p_idstatus NUMBER
) RETURN NUMBER
AS
    v_pct_com NUMBER;
    v_msg VARCHAR2(300);
BEGIN
    BEGIN
        SELECT comis_status
        INTO v_pct_com
        FROM status
        WHERE p_idstatus = id_status;
    EXCEPTION
      WHEN OTHERS THEN
         v_pct_com := 0.03;
         v_msg := SQLERRM;
         pkg_asig.sp_salvame(seq_error.nextval, $$PLSQL_UNIT, v_msg);
    END;
    RETURN v_pct_com;
END fn_pct_com;

/
/*
--Funcion almacenada que retorna dirección tienda. En caso de error debe retornar TIENDA DESCONOCIDA.
*/
CREATE OR REPLACE FUNCTION fn_tienda (
    p_idtienda NUMBER
) RETURN VARCHAR2
AS
    v_tienda VARCHAR2(50);
    v_msg VARCHAR2(300);
BEGIN
    BEGIN
        SELECT dir_tienda
        INTO v_tienda
        FROM tienda
        WHERE p_idtienda = id_tienda;
    EXCEPTION
      WHEN OTHERS THEN
         v_tienda := 'NO HAY TIENDA REGISTRADA';
         v_msg := SQLERRM;
         pkg_asig.sp_salvame(seq_error.nextval, $$PLSQL_UNIT, v_msg);
    END;
    RETURN v_tienda;
END fn_tienda;

/
/*
--3. PROCEDIMIENTO ALMACENADO: 
--Ppal para hacer el calculo de asignaciones a pagar en el mes del proceso. Se deben procesar todos los vendedores. 
Proceso debe probarse para junio del 2023.
--Integra uso de constructores del package y funciones almacenadas.
--Resultado queda almacenado en tabla det asigna mes
--Se ingresa como parámetro fecha del proceso (año y mes.)

--4. TRIGGER
--Genera la info de TOTALASIGNA_MES, de manera simultánea a det_asigna_mes. 

*/



/*1. PROCEDIMIENTO*/

CREATE OR REPLACE PROCEDURE sp_asig (
    p_fecha VARCHAR2
)
AS 
    CURSOR c_asig IS
        SELECT o.id_orden, o.fec_orden, v.numvendedor, v.runvendedor, 
               v.nombrevendedor, s.nom_status, v.id_tienda, 
               v.sueldobase, v.id_status, o.subtotal
        FROM orden o 
        JOIN vendedor v ON o.numvendedor = v.numvendedor
        JOIN status s ON v.id_status = s.id_status
        WHERE TO_CHAR(o.fec_orden, 'MMYYYY') = p_fecha;
        
        --VARIABLES ESCALARES
        v_comision NUMBER;
        v_asignacion NUMBER;
        v_total_asig NUMBER;
    
BEGIN
    FOR r_asig IN c_asig LOOP
        
        v_comision := ROUND(r_asig.subtotal * fn_pct_com(r_asig.id_status));
        v_asignacion :=  pkg_asig.fn_asig(p_fecha, r_asig.numvendedor, r_asig.id_orden);
        v_total_asig := v_asignacion + v_comision;
        
        dbms_output.put_line(
            SUBSTR(p_fecha, 1, 2) || ' ' || SUBSTR(p_fecha, 3, 6) || ' ' ||
            r_asig.id_orden || ' ' || r_asig.fec_orden || ' ' || 
            r_asig.runvendedor || ' ' || r_asig.nombrevendedor || ' ' || 
            r_asig.nom_status || ' ' ||fn_tienda(r_asig.id_tienda)|| ' ' ||v_asignacion
            ||' '||v_comision ||' '||v_total_asig
        );
        
        INSERT INTO det_asigna_mes VALUES (
            SUBSTR(p_fecha, 1, 2) , SUBSTR(p_fecha, 3, 6) ,
            r_asig.id_orden , r_asig.fec_orden , 
            r_asig.runvendedor , r_asig.nombrevendedor , 
            r_asig.nom_status ,fn_tienda(r_asig.id_tienda),v_asignacion
            ,v_comision ,v_total_asig
        );
        
    END LOOP;
    COMMIT;
END sp_asig;
/

BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE TOTALASIGNA_MES';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE DET_ASIGNA_MES';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ERRASIGNA';
    sp_asig('062023');
    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_error';
    EXECUTE IMMEDIATE 'CREATE SEQUENCE seq_error';
END;



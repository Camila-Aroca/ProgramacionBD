--TRIGGER QUE INSERTA INFO EN LA TABLA CALIFICACION MENSUAL EMPLEADP
CREATE OR REPLACE TRIGGER tr_calificacion 
AFTER INSERT ON detalle_haberes_mensual
FOR EACH ROW
BEGIN
    IF :NEW.total_haberes BETWEEN 400000 AND 700000 THEN
        INSERT INTO calificacion_mensual_empleado (mes, anno, run_empleado, total_haberes, calificacion)
        VALUES (:NEW.mes, :NEW.anno, :NEW.run_empleado, :NEW.total_haberes, 
                'Total haberes: ' || :NEW.total_haberes || '. Califica como empleado con salario bajo.');
    ELSIF :NEW.total_haberes BETWEEN 700001 AND 900000 THEN
        INSERT INTO calificacion_mensual_empleado (mes, anno, run_empleado, total_haberes, calificacion)
        VALUES (:NEW.mes, :NEW.anno, :NEW.run_empleado, :NEW.total_haberes, 
                'Total haberes: ' || :NEW.total_haberes || '. Califica como empleado con salario medio.');
    ELSIF :NEW.total_haberes > 900000 THEN
        INSERT INTO calificacion_mensual_empleado (mes, anno, run_empleado, total_haberes, calificacion)
        VALUES (:NEW.mes, :NEW.anno, :NEW.run_empleado, :NEW.total_haberes, 
                'Total haberes: ' || :NEW.total_haberes || '. Califica como empleado con salario alto.');
    END IF;
END tr_calificacion;

/

CREATE OR REPLACE PACKAGE pkg_ventas AS
    PROCEDURE sp_salvame(p_iderror NUMBER, p_subp VARCHAR2, p_msg VARCHAR2);
    FUNCTION fn_ventas (p_fecha VARCHAR2, p_runempleado VARCHAR2) RETURN NUMBER;
    vp_ventas_mes NUMBER;
END pkg_ventas;    

/

CREATE OR REPLACE PACKAGE BODY pkg_ventas AS
    PROCEDURE sp_salvame (
    p_iderror NUMBER, p_subp VARCHAR2, p_msg VARCHAR2
    )
    AS 
       v_sql VARCHAR2(300); 
    BEGIN
        v_sql := 'INSERT INTO error_calc
                    VALUES (:1, :2, :3)';
        EXECUTE IMMEDIATE v_sql USING p_iderror, p_subp, p_msg;
    END sp_salvame;
    
    FUNCTION fn_ventas (
    p_fecha VARCHAR2, 
    p_runempleado VARCHAR2
    ) RETURN NUMBER
    AS
        v_ventas_mes NUMBER;
    BEGIN
    SELECT NVL(SUM(monto_total_boleta),0)
        INTO v_ventas_mes    
        FROM boleta
        WHERE TO_CHAR(fecha, 'MMYYYY') = p_fecha
        AND run_empleado = p_runempleado
        GROUP BY run_empleado;
        
        pkg_ventas.vp_ventas_mes := v_ventas_mes;
        
        RETURN v_ventas_mes;
    END fn_ventas;

END pkg_ventas;    

/
--FUNCION QUE RETORNA EL PORCENTAJE POR ANTIGUEDAD QUE CORRESPONDE AL EMPLEADO SEGÚN AÑOS TRABAJADOS
CREATE OR REPLACE FUNCTION fn_pct_anti (
  p_runempleado VARCHAR2
) RETURN NUMBER
AS

    v_pct_anti NUMBER;
    v_anti NUMBER;
    v_msg VARCHAR2(300);
BEGIN

    --CALCULO ANTIGUEDAD
    select ROUND(MONTHS_BETWEEN(SYSDATE, fecha_contrato)/12)
    into v_anti
    from empleado
    where run_empleado = p_runempleado;
    
    --CALCULO PCT ANTIGUEDAD
    BEGIN
        select porc_antiguedad/100
        into v_pct_anti
        FROM porcentaje_antiguedad
        where v_anti between annos_antiguedad_inf and annos_antiguedad_sup;
    EXCEPTION
        WHEN OTHERS THEN 
        v_msg := SQLERRM;
        v_pct_anti := 0;
        pkg_ventas.sp_salvame(seq_error.nextval, $$PLSQL_UNIT, v_msg);
    
    END;
     
    return v_pct_anti;
END fn_pct_anti;
/


CREATE OR REPLACE FUNCTION fn_com_ventas (
 p_fecha VARCHAR2, p_runempleado VARCHAR2
) RETURN NUMBER
AS
   v_venta NUMBER;
   v_pct_comision NUMBER;
   v_comision NUMBER;
BEGIN
    v_venta := pkg_ventas.fn_ventas(p_fecha, p_runempleado);
    SELECT porc_comision/100
    INTO v_pct_comision
    FROM porcentaje_comision_venta
    WHERE v_venta BETWEEN venta_inf AND venta_sup;
    
    v_comision := ROUND(v_venta * v_pct_comision);
    
    RETURN v_comision;

END fn_com_ventas;

/


CREATE OR REPLACE FUNCTION fn_pct_esc (
  p_idesc NUMBER
) RETURN NUMBER
AS

    v_pct_esc NUMBER;
    v_sql VARCHAR2(300);
    v_msg VARCHAR2(300);
BEGIN    
    BEGIN
            v_sql := 'SELECT porc_escolaridad/100
                      FROM porcentaje_escolaridad pe JOIN empleado e
                      ON pe.cod_escolaridad = e.cod_escolaridad
                      WHERE pe.cod_escolaridad = :1';
            
            EXECUTE IMMEDIATE v_sql INTO v_pct_esc USING p_idesc;
        EXCEPTION
            WHEN OTHERS THEN
             v_pct_esc := 0;
             v_msg := SQLERRM;
             pkg_ventas.sp_salvame(seq_error.nextval, $$PLSQL_UNIT, v_msg);
    END;
     
    return v_pct_esc;
END fn_pct_esc;
/

CREATE OR REPLACE PROCEDURE sp_haberes (
    p_fecha varchar2,
    p_movilizacion NUMBER,
    p_colacion NUMBER
)

AS
CURSOR c_haberes IS
    SELECT e.run_empleado, e.nombre||' '||e.paterno||' '||e.materno nombre, e.sueldo_base, e.cod_escolaridad,
    TO_CHAR(b.fecha, 'MMYYYY'), e.fecha_contrato
    FROM empleado e 
    JOIN boleta b ON e.run_empleado = b.run_empleado
    WHERE TO_CHAR(b.fecha, 'MMYYYY') = p_fecha
    GROUP BY e.run_empleado, TO_CHAR(b.fecha, 'MMYYYY'), e.sueldo_base, 
    e.cod_escolaridad, e.fecha_contrato, e.nombre, e.paterno, e.materno    
    ORDER BY e.run_empleado;
    
    --VARIABLES ESCALARES
    v_asig_anti NUMBER;
    v_asig_esc NUMBER;
    v_total_haberes NUMBER;
    
BEGIN
    FOR r_haberes IN c_haberes LOOP
    
    --CALCULO DE ASIGNACION POR AÑOS TRABAJADOS: % DE VENTAS DEL MES
    v_asig_anti := ROUND(pkg_ventas.fn_ventas(p_fecha, r_haberes.run_empleado)*fn_pct_anti(r_haberes.run_empleado));
    v_asig_esc := ROUND(r_haberes.sueldo_base * fn_pct_esc(r_haberes.cod_escolaridad));
    v_total_haberes := r_haberes.sueldo_base + p_colacion + p_movilizacion + v_asig_anti + v_asig_esc 
                        + fn_com_ventas(p_fecha, r_haberes.run_empleado);
    
        DBMS_OUTPUT.PUT_LINE(
            SUBSTR(p_fecha, 1,2)
            ||' '||substr(p_fecha, 3,6)
            ||' '||r_haberes.run_empleado
            ||' '||r_haberes.nombre
            ||' '||r_haberes.sueldo_base
            ||' '||p_colacion
            ||' '||p_movilizacion
            ||' '||v_asig_anti
            ||' '||v_asig_esc
            ||' '||fn_com_ventas(p_fecha, r_haberes.run_empleado)
            ||' '||v_total_haberes

        );
        
     INSERT INTO detalle_haberes_mensual VALUES (
            SUBSTR(p_fecha, 1,2)
            ,substr(p_fecha, 3,6)
            ,r_haberes.run_empleado
            ,r_haberes.nombre
            ,r_haberes.sueldo_base
            ,p_colacion
            ,p_movilizacion
            ,v_asig_anti
            ,v_asig_esc
            ,fn_com_ventas(p_fecha, r_haberes.run_empleado)
            ,v_total_haberes
     );   
        
    END LOOP;
    COMMIT;
END;

/

begin
    EXECUTE IMMEDIATE 'TRUNCATE TABLE DETALLE_HABERES_MENSUAL';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE CALIFICACION_MENSUAL_EMPLEADO';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE ERROR_CALC';
    sp_haberes('062022', 60000, 75000);
    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_error';
    EXECUTE IMMEDIATE 'CREATE SEQUENCE seq_error';
end;
    
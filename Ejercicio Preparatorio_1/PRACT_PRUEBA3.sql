--FINAL: TRIGGER QUE CALCULA PUNTOS QUE DEBEN OTORGARSE, 150 PUNTOS X 100000 DEL TOTAL DE LA TABLA DETALLE
CREATE OR REPLACE TRIGGER tr_puntos 
BEFORE INSERT ON detalle_diario_huespedes
FOR EACH ROW
DECLARE
BEGIN
    INSERT INTO puntos_mes_huesped
    VALUES (:NEW.id_huesped, :NEW.nombre, :NEW.total, ROUND((:NEW.total/100000)*150));
END tr_puntos;



/

--TERCERO: CREAR PACKAGE QUE DEBE CONTENER
--PROCEDIMIENTO QUE PERMITA GUARDAR DETALLE DE LOS ERRORES EN TABLA CORRESPONDIENTE
--FUNCION QUE DETERMINA MONTO EN DOLARES DE TOURS QUE HA TOMADO EL HUESPED
--VARIABLE QUE SE PUEDA USAR EN EL PROCEDIMIENTO PRINCIPAL PARA RECUPERAR LO QUE DEBE
    --PAGAR EL HUESPED POR TOURS SEGUN LO QUE DEVUELVE LA FUNCION ANTERIOR 


--ENCABEZADO DEL PACKAGE
CREATE OR REPLACE PACKAGE pkg_huespedes AS
    PROCEDURE sp_salvame (p_iderror NUMBER, p_nomsubp VARCHAR2, p_msg VARCHAR2);
    FUNCTION fn_tour (p_idhuesped NUMBER) RETURN NUMBER;
    vp_tour_huesped NUMBER; --Me gustaria utilizar esta variable publica para almacenar el return de la funcion fn_tour
END pkg_huespedes;

/

--BODY DEL PACKAGE
CREATE OR REPLACE PACKAGE BODY pkg_huespedes AS
--SUBPROGRAMA CAPTURA ERRORES
    PROCEDURE sp_salvame (
    p_iderror NUMBER, p_nomsubp VARCHAR2, p_msg VARCHAR2
    )
    AS 
       v_sql VARCHAR2(300); 
    BEGIN
        v_sql := 'INSERT INTO reg_errores
                    VALUES (:1, :2, :3)';
        EXECUTE IMMEDIATE v_sql USING p_iderror, p_nomsubp, p_msg;
    END sp_salvame;
--FUNCION PARA OBTENER VALOR DEL TOUR EN DOLARES POR HUESPED
    FUNCTION fn_tour (
    p_idhuesped NUMBER
    ) RETURN NUMBER
    AS 
        v_monto_tour NUMBER;
    BEGIN
        SELECT NVL(SUM(t.valor_tour * ht.num_personas),0)
        INTO v_monto_tour
        FROM huesped_tour ht JOIN tour t
        ON ht.id_tour = t.id_tour
        WHERE ht.id_huesped = p_idhuesped;   
        RETURN v_monto_tour;
    END fn_tour;
    
END pkg_huespedes;

/

--CUARTO FUNCION ALMACENADA QUE RETORNA AGENCIA DEL HUESPED O CLIENTE, USANDO SQL DINAMICO E INCLUYENDO
--CONTROL DE ERRORES
CREATE OR REPLACE FUNCTION fn_agencia (
   p_idagencia number
) return varchar2
as
  v_sql VARCHAR2(300);
  v_agencia VARCHAR2(80);
  v_msg VARCHAR2(300);
begin
    begin
          v_sql := 'SELECT nom_agencia
                    FROM agencia
                    WHERE id_agencia = :1';
          EXECUTE IMMEDIATE v_sql INTO v_agencia USING p_idagencia;
    EXCEPTION
        WHEN OTHERS THEN
            v_msg := SQLERRM;
            v_agencia := 'NO POSEE AGENCIA';
            pkg_huespedes.sp_salvame(sq_error.nextval, $$PLSQL_UNIT, v_msg);
    END;
  RETURN v_agencia;
end fn_agencia;


/

--QUINTO
--FUNCION ALMACENADA QUE DETERMINA EL MONTO EN DOLARES DE LOS CONSUMOS DEL HUESPED, USANDO TABLA TOTAL_CONSUMOS
--SI HUESPED NO REGISTRA CONSUMOS, DEBE DEVOLVER 0

CREATE OR REPLACE FUNCTION fn_consumos (
    p_idhuesped NUMBER
) RETURN NUMBER
AS
    v_mconsumos NUMBER;
    v_sql VARCHAR2(300);
    v_msg VARCHAR2(300);
BEGIN
    BEGIN
        v_sql := 'SELECT NVL(monto_consumos, 0)
                  FROM total_consumos
                  WHERE id_huesped = :1';
        EXECUTE IMMEDIATE v_sql INTO v_mconsumos USING p_idhuesped;
    EXCEPTION
      WHEN OTHERS THEN
         v_mconsumos := 0;
         v_msg := SQLERRM;
         pkg_huespedes.sp_salvame(SQ_ERROR.nextval, $$PLSQL_UNIT, v_msg);
    END;
    RETURN v_mconsumos;
END fn_consumos;
/

CREATE OR REPLACE FUNCTION fn_dcto_consumo (
 p_idhuesped NUMBER
) RETURN NUMBER
AS
   v_mconsumos NUMBER;
   v_dcto_consumo NUMBER;
   v_pct NUMBER;
BEGIN
    v_mconsumos := fn_consumos(p_idhuesped);
    SELECT nvl(pct,0)
    INTO v_pct
    FROM tramos_consumos
    WHERE v_mconsumos BETWEEN vmin_tramo AND vmax_tramo;
    
    v_dcto_consumo := ROUND(v_mconsumos * v_pct);
    
    RETURN v_dcto_consumo;

END fn_dcto_consumo;

/



--PRIMERO: CREAMOS EL PROCEDIMIENTO PRINCIPAL INCLUYENDO EL CURSOR QUE RECUPERA LOS
--DATOS DE LA TABLA QUE NO REQUIERAN SER CALCULADOS EN FUNCIONES O EN OTROS
--SUBPROGRAMAS
CREATE OR REPLACE PROCEDURE sp_huespedes (
    p_dolar NUMBER, p_fecha VARCHAR2
)
AS
    CURSOR c_huespedes IS


    select h.id_huesped, h.nom_huesped||' '||h.appat_huesped
    ||' '||h.apmat_huesped nom_huesped, h.id_agencia, SUM(ha.valor_habitacion +
    ha.valor_minibar) * r.estadia alojamiento
    from reserva r join huesped h
    ON r.id_huesped = h.id_huesped
    JOIN detalle_reserva dr
    ON dr.id_reserva = r.id_reserva
    JOIN habitacion ha
    ON ha.id_habitacion = dr.id_habitacion 
    where to_char(ingreso + estadia, 'mm/yyyy') = p_fecha
    group by h.id_huesped, h.nom_huesped, h.appat_huesped, 
    h.apmat_huesped, h.id_agencia, r.estadia;
    
    
    --VARIABLES ESCALARES
    v_subtotal NUMBER;
    v_dcto_agencia NUMBER;
    v_total NUMBER;
    v_sql VARCHAR2(400);
    
BEGIN
    --SEGUNDO, EL LOOP FOR PARA ITERAR Y HACER PRUEBAS
    FOR r_huespedes IN c_huespedes LOOP
    
    v_subtotal := (r_huespedes.alojamiento + pkg_huespedes.fn_tour(r_huespedes.id_huesped) + 
             fn_consumos(r_huespedes.id_huesped));
             
    v_dcto_agencia := round(v_subtotal * CASE fn_agencia(r_huespedes.id_agencia)
                                   WHEN 'VIAJES ALBERTI' THEN 0.1 
                                   WHEN 'VIAJES ENIGMA' THEN 0.2 
                                   ELSE 0
                                   END);
    v_total := v_subtotal - fn_dcto_consumo(r_huespedes.id_huesped)- v_dcto_agencia;
    
    --ZONA DE PRUEBA
   /* DBMS_OUTPUT.PUT_LINE(r_huespedes.id_huesped
    ||' '||r_huespedes.nom_huesped
    ||' '||fn_agencia(r_huespedes.id_agencia)
    ||' '||r_huespedes.alojamiento * p_dolar
    ||' '||fn_consumos(r_huespedes.id_huesped) * p_dolar
    ||' '||pkg_huespedes.fn_tour(r_huespedes.id_huesped) * p_dolar
    ||' '||v_subtotal * p_dolar
    ||' '||fn_dcto_consumo(r_huespedes.id_huesped)*p_dolar
    ||' '||v_dcto_agencia * p_dolar
    ||' '||v_total * p_dolar
    );*/
    
    v_sql := 'INSERT INTO detalle_diario_huespedes
                VALUES (:1, :2, :3, :4, :5, :6, :7, :8, :9, :10)';
            EXECUTE IMMEDIATE v_sql USING r_huespedes.id_huesped
            ,r_huespedes.nom_huesped
            ,fn_agencia(r_huespedes.id_agencia)
            ,r_huespedes.alojamiento * p_dolar
            ,fn_consumos(r_huespedes.id_huesped) * p_dolar
            ,pkg_huespedes.fn_tour(r_huespedes.id_huesped) * p_dolar
            ,v_subtotal * p_dolar
            ,fn_dcto_consumo(r_huespedes.id_huesped)*p_dolar
            ,v_dcto_agencia * p_dolar
            ,v_total * p_dolar;
    
    END LOOP;
    COMMIT;
END sp_huespedes;

/

begin
    EXECUTE IMMEDIATE 'TRUNCATE TABLE puntos_mes_huesped';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE detalle_diario_huespedes';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE reg_errores';
    sp_huespedes(840, '08/2023');
    EXECUTE IMMEDIATE 'DROP SEQUENCE sq_error';
    EXECUTE IMMEDIATE 'CREATE SEQUENCE sq_error';
end;

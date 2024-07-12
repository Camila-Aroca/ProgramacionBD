CREATE OR REPLACE TRIGGER TR_ASIGNACIONES_MES
BEFORE INSERT ON detalleasignaciones_mes
FOR EACH ROW
DECLARE
BEGIN
   UPDATE asignaciones_mes_proceso
      SET total_asignaciones = total_asignaciones + :NEW.total_asignaciones
   WHERE runempleado = :NEW.run_empleado;       
END TR_ASIGNACIONES_MES;
/

CREATE OR REPLACE PACKAGE pkg_ventas AS
   v_numero NUMBER;
   PROCEDURE sp_salvaerrores (p_num NUMBER, p_subp VARCHAR2, p_desc VARCHAR2);
   FUNCTION fn_asignacion (p_total NUMBER) RETURN NUMBER;
END pkg_ventas;
/

CREATE OR REPLACE PACKAGE BODY pkg_ventas AS

   FUNCTION fn_asignacion (
      p_total NUMBER
   ) RETURN NUMBER
   AS
      v_pct NUMBER;
   BEGIN
     SELECT pct_asignacion
     INTO v_pct
     FROM pct_asignacion_ventas
     WHERE p_total BETWEEN monto_inf AND monto_sup;
     RETURN ROUND(p_total * v_pct);
   END fn_asignacion;
   
   PROCEDURE sp_salvaerrores (
     p_num NUMBER, p_subp VARCHAR2, p_desc VARCHAR2
   )
   AS
       v_sql VARCHAR2(300);
   BEGIN
       v_sql := 'INSERT INTO errores
                 VALUES (:1, :2, :3)';
       EXECUTE IMMEDIATE v_sql USING p_num, p_subp, p_desc;          
   END sp_salvaerrores;

END pkg_ventas;
/

CREATE OR REPLACE FUNCTION fn_pctcat (
  p_idcat NUMBER, p_runemp VARCHAR2
) RETURN NUMBER
AS
   v_pct NUMBER;
   v_msg VARCHAR2(300);
BEGIN
   BEGIN 
       EXECUTE IMMEDIATE 'SELECT comis_categ
                          FROM categoria
                          WHERE id_categ = :1'
       INTO v_pct USING p_idcat;
   EXCEPTION
      WHEN OTHERS THEN
         v_pct := 0.05;
         v_msg := SQLERRM;
         pkg_ventas.sp_salvaerrores(secuencia_error.NEXTVAL,
            'Error en la función ' || $$PLSQL_UNIT || ' al recuperar el % correspondiente a la categoria del empleado run Nro. '|| p_runemp,
            v_msg);
   END;
   RETURN v_pct;
END fn_pctcat;
/

CREATE OR REPLACE FUNCTION fn_sucursal ( 
  p_idsuc NUMBER, p_idped NUMBER
) RETURN VARCHAR2
AS
   v_sucursal sucursal.dir_suc%type;
   v_sql VARCHAR2(300);
   v_msg VARCHAR2(300);
BEGIN
   BEGIN
       v_sql := 'SELECT dir_suc
                 FROM sucursal
                 WHERE id_suc = :1'; 
       EXECUTE IMMEDIATE v_sql INTO v_sucursal USING p_idsuc;
   EXCEPTION
      WHEN OTHERS THEN
         v_msg := SQLERRM;
         v_sucursal := 'Sucursal desconocida';
         pkg_ventas.sp_salvaerrores(secuencia_error.NEXTVAL,
             'Error en la función ' || $$PLSQL_UNIT || ' al recuperar la sucursal en que se atendió el pedido ' || p_idped,
             v_msg);
   END;   
   RETURN v_sucursal;
END fn_sucursal;
/

CREATE OR REPLACE FUNCTION fn_categoria ( 
  p_idcat NUMBER, p_runemp VARCHAR2
) RETURN VARCHAR2
AS
   v_cat categoria.nom_categ%type;
   v_sql VARCHAR2(300);
   v_msg varchar2(300);
BEGIN
   BEGIN
       v_sql := 'SELECT nom_categ
                 FROM categoria
                 WHERE id_categ = :1'; 
       EXECUTE IMMEDIATE v_sql INTO v_cat USING p_idcat;
   EXCEPTION
      WHEN OTHERS THEN
         v_msg := sqlerrm; 
         v_cat := 'Categoria no asignada';
         pkg_ventas.sp_salvaerrores(secuencia_error.NEXTVAL,
           'Error en la función ' || $$PLSQL_UNIT || ' al recuperar la categoría del empleado run Nro. '|| p_runemp,
            v_msg);
   END;   
   RETURN v_cat;
END fn_categoria;
/

CREATE OR REPLACE PROCEDURE sp_procesa_ventas (
   p_fecha VARCHAR2
)
AS
     CURSOR c1 IS
     SELECT EXTRACT(MONTH FROM fec_pedido) mes, EXTRACT(YEAR FROM fec_pedido) AÑO,
            p.fec_pedido, e.runempleado, e.nombreemp, e.id_suc, e.id_categ,
            p.id_pedido, p.total
     FROM pedido p join empleado e 
     ON p.numempleado = e.numempleado
     WHERE TO_CHAR(fec_pedido, 'MM/YYYY') = p_fecha
     ORDER BY p.id_pedido;
     
     v_asicat number;
BEGIN
     EXECUTE IMMEDIATE 'TRUNCATE TABLE errores';
     EXECUTE IMMEDIATE 'TRUNCATE TABLE detalleasignaciones_mes';
     FOR r1 IN c1 LOOP
         
         -- calculo del monto de asignacion por categoria del empleado 
         v_asicat := ROUND(r1.total * fn_pctcat(r1.id_categ, r1.runempleado));

/*         
         dbms_output.put_line(r1.mes
            || ' ' || r1.año
            || ' ' || r1.id_pedido         
            || ' ' || r1.fec_pedido
            || ' ' || r1.runempleado
            || ' ' || r1.nombreemp
            || ' ' || fn_categoria(r1.id_categ, r1.runempleado)
            || ' ' || fn_sucursal(r1.id_suc, r1.id_pedido)
            || ' ' || pkg_ventas.fn_asignacion(r1.total)
            || ' ' || v_asicat
            || ' ' || (pkg_ventas.fn_asignacion(r1.total) + v_asicat)
            );

*/

         INSERT INTO detalleasignaciones_mes 
         VALUES (r1.mes
            ,r1.año
            ,r1.id_pedido         
            ,r1.fec_pedido
            ,r1.runempleado
            ,r1.nombreemp
            ,fn_categoria(r1.id_categ, r1.runempleado)
            ,fn_sucursal(r1.id_suc, r1.id_pedido)
            ,pkg_ventas.fn_asignacion(r1.total)
            ,v_asicat
            ,(pkg_ventas.fn_asignacion(r1.total) + v_asicat)
            );
     END LOOP;
     COMMIT;
end sp_procesa_ventas;
/

BEGIN
   sp_procesa_ventas('09/2023');
   EXECUTE IMMEDIATE 'DROP SEQUENCE SECUENCIA_ERROR';
   EXECUTE IMMEDIATE 'CREATE SEQUENCE SECUENCIA_ERROR';
END;

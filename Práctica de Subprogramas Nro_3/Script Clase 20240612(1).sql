CREATE OR REPLACE PROCEDURE sp_salvame (
  p_iderror number, p_subp VARCHAR2, p_msg VARCHAR2
)
AS
   v_sql varchar2(300);
BEGIN
   v_sql := 'INSERT INTO error_proceso
             VALUES (:1, :2, :3)';
   EXECUTE IMMEDIATE v_sql USING p_iderror, p_subp, p_msg;          
END sp_salvame;
/

CREATE OR REPLACE FUNCTION fn_autor (
   p_tituloid number
) return varchar2
as
  v_sql VARCHAR2(300);
  v_autor VARCHAR2(80);
begin
  v_sql := 'SELECT nombre || '' '' || apellidos
            FROM AUTOR
            WHERE tituloid = :1';
  EXECUTE IMMEDIATE v_sql INTO v_autor USING p_tituloid;
  RETURN v_autor;
end fn_autor;
/

CREATE OR REPLACE FUNCTION fn_nombre_libro (
  p_tituloid NUMBER
) RETURN VARCHAR2
AS
   v_sql VARCHAR2(400);
   v_nombre titulo.titulo%TYPE;
BEGIN
   v_sql := 'SELECT titulo
             FROM titulo
             WHERE tituloid = :1';
   EXECUTE IMMEDIATE v_sql INTO v_nombre USING p_tituloid;
   RETURN v_nombre;
END fn_nombre_libro;
/

CREATE OR REPLACE FUNCTION fn_nombre_libro2 (
  p_tituloid NUMBER
) RETURN VARCHAR2
AS
   v_nombre titulo.titulo%TYPE;
BEGIN
   EXECUTE IMMEDIATE 'SELECT titulo
                      FROM titulo
                      WHERE tituloid = :1'
   INTO v_nombre USING p_tituloid;
   
   RETURN v_nombre;
END fn_nombre_libro2;
/

-- ENCABEZADO DEL PACKAGE
CREATE OR REPLACE PACKAGE pkg_multas AS
   vp_editorial VARCHAR2(30);
   vp_escuela VARCHAR2(30);
   FUNCTION fn_editorial (p_editorialid NUMBER) RETURN VARCHAR2;
   FUNCTION fn_escuela (p_carreraid NUMBER) RETURN VARCHAR2;
END pkg_multas;
/

CREATE OR REPLACE PACKAGE BODY pkg_multas AS

   FUNCTION fn_escuela (
     p_carreraid NUMBER
   ) RETURN VARCHAR2
   AS
      v_sql VARCHAR2(300);
      v_escuela VARCHAR2(30);
      v_msg VARCHAR2(300);
   BEGIN
      BEGIN
          v_sql := 'SELECT e.descripcion
                    FROM escuela e JOIN carrera c
                    ON e.escuelaid = c.escuelaid
                    WHERE c.carreraid = :1';
          EXECUTE IMMEDIATE v_sql INTO v_escuela USING p_carreraid;
      EXCEPTION
         WHEN OTHERS THEN
            v_msg := SQLERRM;
            v_escuela := 'NO POSEE ESCUELA';
            sp_salvame(sq_error.NEXTVAL, $$PLSQL_UNIT, v_msg);
      END;
      RETURN v_escuela;
   END fn_escuela;

   FUNCTION fn_editorial (
     p_editorialid NUMBER
   ) RETURN VARCHAR2
   AS
      v_sql VARCHAR2(300);
      v_editorial VARCHAR2(30);
   BEGIN
      v_sql := 'SELECT descripcion
                FROM editorial
                WHERE editorialid = :1';
      EXECUTE IMMEDIATE v_sql INTO v_editorial USING p_editorialid;
      RETURN v_editorial;
   END fn_editorial;

END pkg_multas;
/


CREATE OR REPLACE PROCEDURE sp_procesa_prestamos (
  p_fecha VARCHAR2
)
AS
   CURSOR c_prestamos IS
   SELECT e.nombre|| ' ' || e.apaterno || ' ' || e.amaterno nom_empleado,
          p.fecha_inicio, p.fecha_termino, p.fecha_entrega,
          p.tituloid, al.carreraid, t.editorialid,
          al.nombre || ' ' || al.apaterno || ' ' || al.amaterno nom_alumno
   FROM prestamo p JOIN alumno al 
   ON al.alumnoid = p.alumnoid
   JOIN empleado e ON e.empleadoid = p.empleadoid
   JOIN titulo t ON t.tituloid = p.tituloid 
   WHERE TO_CHAR(p.fecha_termino, 'MM/YYYY') = p_fecha;
BEGIN
   FOR r_prestamos IN c_prestamos LOOP
      
      DBMS_OUTPUT.PUT_LINE(c_prestamos%ROWCOUNT
        || ' ' || p_fecha
        || ' ' || fn_nombre_libro(r_prestamos.tituloid)
        || ' ' || pkg_multas.fn_editorial(r_prestamos.editorialid)
        || ' ' || fn_autor(r_prestamos.tituloid)
        || ' ' || r_prestamos.nom_alumno
        || ' ' || pkg_multas.fn_escuela(r_prestamos.carreraid)
        || ' ' || r_prestamos.nom_empleado
        || ' ' || r_prestamos.fecha_inicio
        || ' ' || r_prestamos.fecha_termino
        || ' ' || r_prestamos.fecha_entrega
        );
      
   END LOOP;
END sp_procesa_prestamos;
/

begin
  sp_procesa_prestamos('08/2023');
end;
/


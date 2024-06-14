-- SINTAXIS INSTRUCCIONES SQL DINAMICO
-- Sentencias SQL se construyen sobre la marcha, 
-- basadas en un conjunto de parámetros especificados en tiempo de ejecución.

-- USO DE SQL DINAMICO NATIVO 
-- SINTAXIS DE LA SENTENCIA EXECUTE IMMEDIATE

/*
EXECUTE IMMEDIATE string_dinámico
[INTO variable1, variable2, ...] 
[USING [IN|OUT|IN OUT] argumento1, argumento2, ...] 
[RETURNING INTO|RETURN argumento1, argumento2, ...]

En la sintaxis:
string_dinámico: es una cadena literal, VARIABLE o expresión 
que representa una sola sentencia SQL o un bloque PL / SQL. 
Debe ser DEL tipo CHAR o VARCHAR2.
INTO: utilizado solo para consultas de una sola fila. 
      Esta cláusula especifica las variables o registro en los que se recuperan 
      los valores de la columna. Para cada valor recuperado por la consulta,
      debe haber una VARIABLE o campo correspondiente.
USING: especifica una lista de argumentos de entrada y/o salida 
       que se asocian A las variables usadas en la sentencia SQL. 
       El modo de parámetro predeterminado es IN. 
       Los parámetros deben ser especificados en el mismo orden en que 
       las variables bind se usan en la sentencia.
RETURN[ING] INTO: se usa en las sentencias INSERT, UPDATE Y DELETE 
       que tienen una cláusula RETURN. 
       Para cada valor retornado por la sentencia debe haber una 
       VARIABLE correspondiente en la cláusula RETURN INTO
*/

/*
-- USO DEL PACKAGE DBMS_SQL
-- PERMITE UTILIZAR SQL DINAMICO
El PACKAGE DBMS_SQL posee los siguientes subprogramas:

OPEN_CURSOR: se utiliza para abrir un nuevo CURSOR y 
             retornar un número de identificación DEL CURSOR.
DBMS_SQL.OPEN_CURSOR
PARSE: se utiliza para analizar la sentencia SQL. Verifica la sintaxis
       de la sentencia y la asocia con el cursor. Puede analizar 
       sentencias DML o DDL. Las sentencias DDL se ejecutan inmediatamente 
       cuando se analizan.
BIND_VARIABLE: se utiliza para vincular un determinado valor 
       a una variable bind identificada por su nombre en la sentencia
       que se está analizando. Esto NO es necesario si la sentencia
       no tiene variables bind.
EXECUTE: utilizada para ejecutar la sentencia SQL y 
         devolver el número de filas procesadas
CLOSE_CURSOR: se utiliza para cerrar el CURSOR especificado
*/


/* ============================================================================
   SCRIPT 2: LIMPIEZA E IMPUTACIÓN
   ----------------------------------------------------------------------------
   En este script se documentan los procesos de limpieza e imputación 
   necesarios para garantizar el manejo adecuado de los datos. Se eliminan 
   los registros que no aportan información útil para el estudio y se 
   se imputan los datos faltantes de las variables temporales.
   ============================================================================ */


-- ELIMINACIÓN DE REGISTROS SIN HORA DE DESCUBRIMIENTO
-- ----------------------------------------------------------------------------
/* Para calcular la duración exacta de un incendio es necesario conocer la 
   hora de inicio. Los registros con DISCOVERY_TIME nulo no pueden ser 
   imputados, al ser una variable importante para la investigación se decidio 
   eliminar estos registros */

DELETE FROM fire_event 
WHERE DISCOVERY_TIME IS NULL OR DISCOVERY_TIME = '';



-- IMPUTACIÓN DE HORAS Y FECHAS DE CONTENCIÓN
-- ----------------------------------------------------------------------------
/* Al quedar registros con hora de descubrimiento pero sin hora de contención
   se procedio a imputar por promedio, se calculó la duración promedio en
   horas para cada clase de tamaño y se le sumó a la hora de descubrimiento. */


-- Creación de la  tabla temporal con los promedios por clase
CREATE TABLE promedios AS
SELECT 
    FIRE_SIZE_CLASS,
    AVG(
        (
            (CAST(substr(CONT_TIME, 1, 2) AS REAL) * 60 + CAST(substr(CONT_TIME, 3, 2) AS REAL)) -
            (CAST(substr(DISCOVERY_TIME, 1, 2) AS REAL) * 60 + CAST(substr(DISCOVERY_TIME, 3, 2) AS REAL))
        ) / 60.0
    ) AS promedio_horas
FROM fire_event
WHERE CONT_TIME IS NOT NULL 
  AND DISCOVERY_TIME IS NOT NULL
  AND DISCOVERY_DATE = CONT_DATE
GROUP BY FIRE_SIZE_CLASS;


-- Imputación de la hora de contención
UPDATE fire_event
SET CONT_TIME = time(
    substr(DISCOVERY_TIME, 1, 2) || ':' || substr(DISCOVERY_TIME, 3, 2) || ':00',
    '+' || (
        SELECT ROUND(p.promedio_horas, 2) 
        FROM promedios p 
        WHERE p.FIRE_SIZE_CLASS = fire_event.FIRE_SIZE_CLASS
    ) || ' hours'
)
WHERE CONT_TIME IS NULL AND DISCOVERY_TIME IS NOT NULL ;



-- Imputación de la fecha de contención 
UPDATE fire_event 
SET CONT_DATE = DISCOVERY_DATE, 
    CONT_DOY = DISCOVERY_DOY 
WHERE CONT_DATE IS NULL;


-- Ajuste de la fecha si la hora de contención imputada cruzó la medianoche
UPDATE fire_event
SET CONT_DATE = date(DISCOVERY_DATE, '+1 day'),
    CONT_DOY = CONT_DOY + 1
WHERE CONT_TIME < DISCOVERY_TIME
  AND CONT_TIME IS NOT NULL
  AND DISCOVERY_TIME IS NOT NULL
  AND CONT_DATE = DISCOVERY_DATE;


-- Se elimina la tabla temporal
DROP TABLE promedios;


-- FILTRO POR ESTADO
-- ----------------------------------------------------------------------------
/* La investigación se centra en California (CA), Texas (TX) y Oregón (OR)
   por su alta incidencia de incendios. Se eliminan los demás estados por
   su falta de relevancia en el estudio. */

DELETE FROM fire_event 
WHERE STATE NOT IN ('CA', 'TX', 'OR');

DELETE FROM county 
WHERE STATE NOT IN ('CA', 'TX', 'OR');



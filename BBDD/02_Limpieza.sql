/* ============================================================================
   SCRIPT 2: LIMPIEZA E IMPUTACIÓN
   ----------------------------------------------------------------------------
   Una vez normalizada la base de datos, es necesario aplicar reglas de 
   negocio y limpieza para garantizar la calidad del análisis estadístico. 
   Este script documenta el filtro geográfico, la eliminación de registros 
   sin hora (inservibles para calcular duración) y la imputación de fechas.
   ============================================================================ */


-- BLOQUE 1: FILTRO GEOGRÁFICO (Solo 3 estados de interés)
-- ----------------------------------------------------------------------------
/* Justificación: La investigación se centra en California (CA), Texas (TX) 
   y Oregón (OR) por su alta incidencia de incendios. Se eliminan los demás 
   estados para reducir el sesgo y optimizar el rendimiento de las consultas. */

DELETE FROM fire_event 
WHERE STATE NOT IN ('CA', 'TX', 'OR');

DELETE FROM county 
WHERE STATE NOT IN ('CA', 'TX', 'OR');



-- BLOQUE 2: ELIMINACIÓN DE REGISTROS SIN HORA DE DESCUBRIMIENTO
-- ----------------------------------------------------------------------------
/* Justificación: Para calcular la duración exacta de un incendio es 
   imprescindible conocer la hora de inicio. Los registros con DISCOVERY_TIME 
   nulo no pueden ser imputados sin inventar información, por lo que se 
   descartan del estudio (representan menos del 1% de la muestra). */

DELETE FROM fire_event 
WHERE DISCOVERY_TIME IS NULL OR DISCOVERY_TIME = '';



-- BLOQUE 4: IMPUTACIÓN DE HORAS Y FECHAS DE CONTENCIÓN
-- ----------------------------------------------------------------------------
/* Justificación: Casi la mitad de los registros no tenían hora ni fecha de 
   contención. Para no perder esos datos, se aplicó la técnica de imputación 
   por promedio: se calculó la duración promedio en horas para cada clase de 
   tamaño (A, B, C...) y se le sumó a la hora de descubrimiento. */

-- 4.1 Crear tabla temporal con los promedios por clase
DROP TABLE IF EXISTS temp_promedios;
CREATE TABLE temp_promedios AS
SELECT 
    FIRE_SIZE_CLASS,
    AVG(
        (
            (CAST(substr(CONT_TIME, 1, 2) AS REAL) * 60 + CAST(substr(CONT_TIME, 3, 2) AS REAL)) -
            (CAST(substr(DISCOVERY_TIME, 1, 2) AS REAL) * 60 + CAST(substr(DISCOVERY_TIME, 3, 2) AS REAL))
        ) / 60.0
    ) AS Promedio_Horas
FROM fire_event
WHERE CONT_TIME IS NOT NULL 
  AND DISCOVERY_TIME IS NOT NULL
  AND LENGTH(CONT_TIME) = 4 
  AND LENGTH(DISCOVERY_TIME) = 4
  AND DISCOVERY_DATE = CONT_DATE
GROUP BY FIRE_SIZE_CLASS;

-- Imputar la hora de contención
UPDATE fire_event
SET CONT_TIME = time(
    substr(DISCOVERY_TIME, 1, 2) || ':' || substr(DISCOVERY_TIME, 3, 2) || ':00',
    '+' || (
        SELECT ROUND(t.Promedio_Horas, 2) 
        FROM temp_promedios t 
        WHERE t.FIRE_SIZE_CLASS = fire_event.FIRE_SIZE_CLASS
    ) || ' hours'
)
WHERE CONT_TIME IS NULL 
  AND DISCOVERY_TIME IS NOT NULL 
  AND LENGTH(DISCOVERY_TIME) = 4
  AND FIRE_SIZE_CLASS IS NOT NULL;

-- Imputar la fecha de contención (asumiendo mismo día)
UPDATE fire_event 
SET CONT_DATE = DISCOVERY_DATE, 
    CONT_DOY = DISCOVERY_DOY 
WHERE CONT_DATE IS NULL;

-- Ajustar fecha si la imputación de horas cruzó la medianoche
UPDATE fire_event
SET CONT_DATE = date(julianday(DISCOVERY_DATE) + 1), 
    CONT_DOY = CONT_DOY + 1                          
WHERE CAST(CONT_TIME AS integer) < CAST(DISCOVERY_TIME AS integer) 
  AND CONT_TIME IS NOT NULL 
  AND DISCOVERY_TIME IS NOT NULL
  AND CONT_DATE IS NOT NULL;

-- 4.5 Limpieza de tabla temporal y compactación
DROP TABLE temp_promedios;
VACUUM;
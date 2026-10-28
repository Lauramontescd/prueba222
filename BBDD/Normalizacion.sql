--Creacion de tablas pra el evo esquema normalizado de la base de datos
-- Tabla Condado
CREATE TABLE county (
	STATE varchar (2),
	FIPS_CODE varchar (10),
	FIPS_NAME text,
	PRIMARY KEY (STATE, FIPS_CODE)
)

INSERT INTO county (STATE, FIPS_CODE, FIPS_NAME)
SELECT 
    STATE,
    FIPS_CODE, 
    MAX(FIPS_NAME)
FROM Fires
WHERE FIPS_CODE IS NOT NULL AND STATE IS NOT NULL
GROUP BY STATE, FIPS_CODE;

--Tabla Dueño del terreno
CREATE TABLE owner (
    OWNER_CODE integer PRIMARY KEY,
    OWNER_DESCR text
);

INSERT INTO owner (OWNER_CODE, OWNER_DESCR)
SELECT OWNER_CODE, MAX(OWNER_DESCR)
FROM Fires
WHERE OWNER_CODE IS NOT NULL
GROUP BY OWNER_CODE;

--Tabla de la Causa del Incendio
CREATE TABLE cause (
    STAT_CAUSE_CODE integer PRIMARY KEY,
    STAT_CAUSE_DESCR text
);

INSERT INTO cause (STAT_CAUSE_CODE, STAT_CAUSE_DESCR)
SELECT STAT_CAUSE_CODE, MAX(STAT_CAUSE_DESCR)
FROM Fires
WHERE STAT_CAUSE_CODE IS NOT NULL
GROUP BY STAT_CAUSE_CODE;

--Tabla MTBS
CREATE TABLE mtbs (
	MTBS_ID varchar (25) PRIMARY KEY,
	MTBS_FIRE_NAME text
)

INSERT INTO mtbs (MTBS_ID, MTBS_FIRE_NAME)
SELECT MTBS_ID, MAX(MTBS_FIRE_NAME) FROM Fires
WHERE MTBS_ID IS NOT NULL
GROUP BY MTBS_ID; 

--Tabla de la Unidad de Reporte
CREATE TABLE reporting_unit (
    SOURCE_REPORTING_UNIT varchar(10) PRIMARY KEY,
    SOURCE_REPORTING_UNIT_NAME text
);

INSERT INTO reporting_unit (SOURCE_REPORTING_UNIT, SOURCE_REPORTING_UNIT_NAME)
SELECT SOURCE_REPORTING_UNIT, MAX(SOURCE_REPORTING_UNIT_NAME)
FROM Fires
WHERE SOURCE_REPORTING_UNIT IS NOT NULL
GROUP BY SOURCE_REPORTING_UNIT;

-- Tabla NWCG
CREATE TABLE nwcg (
    UnitId varchar(10) PRIMARY KEY,
    NWCG_REPORTING_AGENCY varchar(10),
    NWCG_REPORTING_UNIT_NAME text, 
    GeographicArea varchar(3),
    Gacc varchar(15),
    WildlandRole text,
    UnitType text,
    Department varchar(10),
    Agency varchar(15),
    Parent varchar(100),
    Country varchar(15),
    State varchar(15),
    Code varchar(10),
    Name text 
);

INSERT INTO nwcg (UnitId, NWCG_REPORTING_AGENCY, NWCG_REPORTING_UNIT_NAME, GeographicArea, Gacc, WildlandRole, UnitType, Department, Agency, Parent, Country, State, Code, Name)
SELECT 
    n.UnitId, 
    MAX(f.NWCG_REPORTING_AGENCY),     
    MAX(f.NWCG_REPORTING_UNIT_NAME),  
    n.GeographicArea, 
    n.Gacc, 
    n.WildlandRole, 
    n.UnitType, 
    n.Department, 
    n.Agency, 
    n.Parent, 
    n.Country, 
    n.State, 
    n.Code,
    MAX(n.Name) 
FROM NWCG_UnitIDActive_20170109 n
LEFT JOIN Fires f ON n.UnitId = f.NWCG_REPORTING_UNIT_ID
WHERE n.UnitId IS NOT NULL
GROUP BY n.UnitId;


--Tabla del Tipo de Sistema
CREATE TABLE system_type (
    SOURCE_SYSTEM_TYPE text PRIMARY KEY
);

INSERT INTO system_type  (SOURCE_SYSTEM_TYPE)
SELECT DISTINCT SOURCE_SYSTEM_TYPE 
FROM Fires 
WHERE SOURCE_SYSTEM_TYPE IS NOT NULL;

--Tabla del sistema de Origen
CREATE TABLE source_system (
    SOURCE_SYSTEM varchar(10) PRIMARY KEY,
    SOURCE_SYSTEM_TYPE text,
    FOREIGN KEY (SOURCE_SYSTEM_TYPE) REFERENCES system_type (SOURCE_SYSTEM_TYPE)
);


INSERT INTO source_system  (SOURCE_SYSTEM, SOURCE_SYSTEM_TYPE)
SELECT 
    SOURCE_SYSTEM, 
    MAX(SOURCE_SYSTEM_TYPE) 
FROM Fires 
WHERE SOURCE_SYSTEM IS NOT NULL
GROUP BY SOURCE_SYSTEM;


--Tabla de Complejo
--Debido a que la tabla original no tenia un ID se genero uno con ROW_NUMBER()
CREATE TABLE complex (
	COMPLEX_ID integer PRIMARY KEY, 
	COMPLEX_NAME text
)

INSERT INTO complex (COMPLEX_id, COMPLEX_NAME)
SELECT 
    ROW_NUMBER() OVER (ORDER BY COMPLEX_NAME) AS COMPLEX_id,
    COMPLEX_NAME
FROM (
    SELECT DISTINCT COMPLEX_NAME 
    FROM Fires 
    WHERE COMPLEX_NAME IS NOT NULL AND COMPLEX_NAME != ''
);



--Tabla de Reporte, contiene los detalles del incidente
--Se uso ROW_NUMBER() para crear un ID a cada reporte
CREATE TABLE report (
    id integer PRIMARY KEY,
    SOURCE_REPORTING_UNIT varchar(10),
    LOCAL_FIRE_REPORT_ID varchar(50),
    LOCAL_INCIDENT_ID varchar(50),
    FIRE_CODE varchar(50),
    FIRE_NAME text,
    FIRE_YEAR integer,
    ICS_209_INCIDENT_NUMBER text,
    ICS_209_NAME text,
    COMPLEX_id integer, 
    FOREIGN KEY (SOURCE_REPORTING_UNIT) REFERENCES reporting_unit(SOURCE_REPORTING_UNIT),
    FOREIGN KEY (COMPLEX_id) REFERENCES complex (COMPLEX_id)
);


INSERT INTO report (
    id, SOURCE_REPORTING_UNIT, LOCAL_FIRE_REPORT_ID, LOCAL_INCIDENT_ID, 
    FIRE_CODE, FIRE_NAME, FIRE_YEAR, ICS_209_INCIDENT_NUMBER, 
    ICS_209_NAME, COMPLEX_id
)
SELECT 
    ROW_NUMBER() OVER (ORDER BY f.FOD_ID) AS id,
    f.SOURCE_REPORTING_UNIT,
    f.LOCAL_FIRE_REPORT_ID,
    f.LOCAL_INCIDENT_ID,
    f.FIRE_CODE,
    f.FIRE_NAME,
    f.FIRE_YEAR,
    f.ICS_209_INCIDENT_NUMBER,
    f.ICS_209_NAME,
    c.COMPLEX_id
FROM Fires f
LEFT JOIN complex c ON f.COMPLEX_NAME = c.COMPLEX_NAME;


--Tabla Principal que contiene los detalles de los incendios 
CREATE TABLE fire_event (
    FOD_ID integer PRIMARY KEY,
    FPA_ID text,
    DISCOVERY_DATE date, 
    DISCOVERY_DOY integer,
    DISCOVERY_TIME text,
    CONT_DATE date,      
    CONT_DOY integer,
    CONT_TIME text,
    FIRE_SIZE float,
    LATITUDE float,
    LONGITUDE float,
    STATE varchar(2),
    FIPS_CODE varchar(10),
    UnitId varchar(50), 
    OWNER_CODE integer,
    STAT_CAUSE_CODE integer,
    MTBS_ID text,
    report_id integer,
    SOURCE_SYSTEM varchar(10), 
    FOREIGN KEY (STATE, FIPS_CODE) REFERENCES county(STATE, FIPS_CODE),
    FOREIGN KEY (UnitId) REFERENCES nwcg(UnitId),
    FOREIGN KEY (OWNER_CODE) REFERENCES owner(OWNER_CODE),
    FOREIGN KEY (STAT_CAUSE_CODE) REFERENCES cause(STAT_CAUSE_CODE),
    FOREIGN KEY (MTBS_ID) REFERENCES mtbs(MTBS_ID),
    FOREIGN KEY (report_id) REFERENCES report(id),
    FOREIGN KEY (SOURCE_SYSTEM) REFERENCES source_system(SOURCE_SYSTEM)
);

SELECT * FROM fire_event fe 

INSERT INTO fire_event (
    FOD_ID, FPA_ID, DISCOVERY_DATE, DISCOVERY_DOY, DISCOVERY_TIME, 
    CONT_DATE, CONT_DOY, CONT_TIME, FIRE_SIZE, LATITUDE, LONGITUDE, 
    STATE, FIPS_CODE, UnitId, OWNER_CODE, STAT_CAUSE_CODE, MTBS_ID, report_id, SOURCE_SYSTEM
)
SELECT 
    f.FOD_ID, 
    f.FPA_ID, 
    date(f.DISCOVERY_DATE), 
    f.DISCOVERY_DOY, 
    f.DISCOVERY_TIME, 
    date(f.CONT_DATE),
    f.CONT_DOY, 
    f.CONT_TIME, 
    f.FIRE_SIZE,
    f.LATITUDE,
    f.LONGITUDE, 
    f.STATE, 
    f.FIPS_CODE,
    f.NWCG_REPORTING_UNIT_ID,
    f.OWNER_CODE, 
    CAST(f.STAT_CAUSE_CODE AS integer), 
    f.MTBS_ID, r.id AS report_id, 
    f.SOURCE_SYSTEM
FROM Fires f
LEFT JOIN report r ON f.FOD_ID = r.id;


--LIMPIEZA
--Eliminando registros cuya fecha de contencion este fuera del rango de 1992 y 2015

DELETE FROM fire_event 
WHERE CONT_DATE < '1992-01-01' OR CONT_DATE > '2015-12-31';







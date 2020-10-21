CREATE OR REPLACE PACKAGE BODY PKG_GESTION_ENCUESTADORMOVIL IS

PROCEDURE GIC_AGREGAR_PERSONA(
  P_Per_Idpersona NUMBER, P_apellido1 NVARCHAR2,P_apellido2 NVARCHAR2,P_nombre1 NVARCHAR2,P_nombre2 NVARCHAR2,
  P_tipoDoc NVARCHAR2, P_documento NVARCHAR2,P_fecNacimiento NVARCHAR2,P_Estado NVARCHAR2,
  P_usu_usuariocreacion NVARCHAR2,P_Usu_FechaCreacion NVARCHAR2,V_SALIDA OUT NVARCHAR2,V_VALSECUENCIA OUT NUMBER)

 AS
 FechaCreacion DATE;
 CfecNacimiento DATE;
 MAX_P_Per_Idpersona NUMBER;
 TotalPersonas NUMBER;

 BEGIN
   SELECT COUNT(*) INTO TotalPersonas
    FROM GIC_PERSONA P
    WHERE (UPPER(P.R_PRIMERNOMBRE) = UPPER(P_nombre1) AND UPPER(P.R_SEGUNDONOMBRE) = UPPER(P_nombre2)
    AND UPPER(P.R_PRIMERAPELLIDO) = UPPER(P_apellido1) AND UPPER(P.R_SEGUNDOAPELLIDO) = UPPER(P_apellido2)) OR
    UPPER(P.R_NUMERODOC) = UPPER(P_documento);

   --dbms_output.put_line(P_Usu_FechaCreacion);
   SELECT TO_DATE(P_Usu_FechaCreacion, 'DD/MM/YYYY HH24:MI:SS') INTO FechaCreacion FROM DUAL;
   SELECT TO_DATE(P_fecNacimiento, 'DD/MM/YYYY') INTO CfecNacimiento FROM DUAL;

   IF TotalPersonas = 0 THEN
             INSERT INTO GIC_PERSONA VALUES(0,UPPER(P_nombre1),UPPER(P_nombre2),
             UPPER(P_apellido1),UPPER(P_apellido2),CfecNacimiento,
             UPPER(P_tipoDoc),UPPER(P_usu_usuariocreacion),
             FechaCreacion,P_documento,NULL,NULL,NULL,NULL,NULL,NULL,UPPER(P_Estado),UPPER(P_nombre1),
             UPPER(P_nombre2),UPPER(P_apellido1),UPPER(P_apellido2),CfecNacimiento,UPPER(P_documento),0,null);
             COMMIT;
             V_SALIDA := 'Insercion ok de miembro no registrado en GIC_PERSONA';
       COMMIT;

       SELECT gic_sec_persona.currval INTO V_VALSECUENCIA FROM DUAL ;

     ELSE
            SELECT P.PER_IDPERSONA INTO V_VALSECUENCIA
            FROM GIC_PERSONA P
            WHERE (P.R_PRIMERNOMBRE = UPPER(P_nombre1) AND P.R_SEGUNDONOMBRE = UPPER(P_nombre2)
            AND P.R_PRIMERAPELLIDO = UPPER(P_apellido1) AND P.R_SEGUNDOAPELLIDO = UPPER(P_apellido2)) OR
            P.R_NUMERODOC = P_documento;

     COMMIT;

   END IF;

   EXCEPTION when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'PKG_GESTION_ENCUESTADORMOVIL.GIC_AGREGAR_PERSONA','ENCUESTADOR MOVIL');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'PKG_GESTION_ENCUESTADORMOVIL.GIC_AGREGAR_PERSONA','ENCUESTADOR MOVIL');
  V_SALIDA := 'Error al insertar en GIC_PERSONA';

 END GIC_AGREGAR_PERSONA;

PROCEDURE GIC_AGREGAR_HOGAR
  (P_hog_codigo NVARCHAR2,P_usu_usuariocreacion NVARCHAR2,P_usu_idusuario NUMBER,P_usu_fechacreacion NVARCHAR2,
                            P_estado NVARCHAR2,
                            V_SALIDA OUT NVARCHAR2)
AS

FechaCreacion DATE;
HOGAR NVARCHAR2(5);
CODIGOHOGAR NUMBER;
V_IdUsuario NUMBER :=50214;

BEGIN

    --HOGAR:= GET_CODIGOHOGAR(usu_usuariocreacion,50214);
    SELECT TO_DATE(P_Usu_FechaCreacion, 'DD/MM/YYYY HH24:MI:SS') INTO FechaCreacion FROM DUAL;
    SELECT COUNT(T.hog_codigo) INTO CODIGOHOGAR FROM gic_hogar T WHERE UPPER(T.hog_codigoENCUESTA) = UPPER(P_hog_codigo);
    SELECT T.IDUSUARIO INTO V_IdUsuario FROM ADMINUSUARIOS.USUARIO@DBLINK_VIVANTO T WHERE UPPER(T.USUARIOINGRESO) = UPPER(P_usu_usuariocreacion);

    IF CODIGOHOGAR > 0 THEN

       SELECT T.hog_codigo INTO HOGAR FROM gic_hogar T WHERE UPPER(T.hog_codigoENCUESTA) = UPPER(P_hog_codigo);       
       V_SALIDA := 'Código de hogar ya existe '||' '|| HOGAR ;

    ELSE

    HOGAR := FN_GET_CODIGOENCUESTA;

    INSERT INTO GIC_HOGAR VALUES(0,UPPER(TRIM(HOGAR)),UPPER(P_usu_usuariocreacion),
    V_IdUsuario,FechaCreacion,2,UPPER(TRIM(P_hog_codigo)),UPPER(P_estado),SYSDATE,UPPER(P_usu_usuariocreacion),'');
    COMMIT;
    
    V_SALIDA := 'Insercion ok en GIC_AGREGAR_HOGAR';
    
    /*
    INSERT INTO auditoriavivantoprod.AUD_CARACTERIZACION_OFFLINE@consultavivanto VALUES(0,UPPER(TRIM(HOGAR)),UPPER(P_usu_usuariocreacion),
    V_IdUsuario,FechaCreacion,2,UPPER(TRIM(P_hog_codigo)),UPPER(P_estado),SYSDATE,UPPER(P_usu_usuariocreacion));
    COMMIT;
    */
    

    END IF;

    EXCEPTION    when others then    
    V_SALIDA := 'Excepción, Error al insertar en GIC_AGREGAR_HOGAR';
    SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'PKG_GESTION_ENCUESTADORMOVIL.GIC_AGREGAR_HOGAR',P_hog_codigo);
    SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'PKG_GESTION_ENCUESTADORMOVIL.GIC_AGREGAR_HOGAR',P_hog_codigo);


END GIC_AGREGAR_HOGAR;

PROCEDURE GIC_AGREGAR_CAPITULOSTER
  (
  P_hog_codigo NVARCHAR2,
  P_id_tema NUMBER,
  P_usu_usuariocreacion NVARCHAR2,
  P_usu_fechacreacion NVARCHAR2,
  V_SALIDA OUT NVARCHAR2
  )
AS

HOGAR NVARCHAR2(5);
CODIGOHOGAR NUMBER;
V_FechaCreacion DATE;

BEGIN

    SELECT COUNT(T.hog_codigo) INTO CODIGOHOGAR FROM gic_hogar T WHERE UPPER(T.hog_codigoENCUESTA) = UPPER(P_hog_codigo);
    SELECT TO_DATE(P_usu_fechacreacion, 'DD/MM/YYYY HH24:MI:SS') INTO V_FechaCreacion FROM DUAL;

    IF CODIGOHOGAR > 0 THEN

    SELECT T.hog_codigo INTO HOGAR FROM gic_hogar T WHERE UPPER(T.hog_codigoENCUESTA) = UPPER(P_hog_codigo);
    INSERT INTO gic_n_CAPITULOS_TER VALUES(HOGAR, P_id_tema, UPPER(P_usu_usuariocreacion),V_FechaCreacion) ;
    COMMIT;
    V_SALIDA := 'Insercion ok en GIC_N_CAPITULOS_TER';
    ELSE
      V_SALIDA := 'Hogar no existe en GIC_N_CAPITULOS_TER';
    END IF;

    EXCEPTION

    WHEN OTHERS THEN
    V_SALIDA := 'Excepcción, Error al insertar en GIC_N_CAPITULOS_TER';
    SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'PKG_GESTION_ENCUESTADORMOVIL.GIC_AGREGAR_CAPITULOSTER',P_hog_codigo);
    SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'PKG_GESTION_ENCUESTADORMOVIL.GIC_AGREGAR_CAPITULOSTER',P_hog_codigo);

END GIC_AGREGAR_CAPITULOSTER;

PROCEDURE GIC_AGREGAR_MIEMBROSHOGAR(p_P_hog_codigo NVARCHAR2,P_Per_Idpersona NUMBER,P_usu_usuariocreacion NVARCHAR2,
  P_usu_fechacreacion NVARCHAR2,P_per_encuestada NVARCHAR2, P_documento NVARCHAR2, P_idpersona_encomu NUMBER,  V_SALIDA OUT NVARCHAR2)

AS

CODIGOHOGAR NUMBER := 0;
HOGAR NVARCHAR2(5);
DOCUMENTO NVARCHAR2(200) := P_documento;
V_idpersona NUMBER :=50214;
V_FechaCreacion DATE;
V_cidpersona NUMBER;
BEGIN
 --dbms_output.put_line(p_P_hog_codigo);
 SELECT COUNT(T.hog_codigo) INTO CODIGOHOGAR FROM GIC_HOGAR T WHERE UPPER(T.hog_codigoENCUESTA) = UPPER(p_P_hog_codigo);
 SELECT TO_DATE(P_usu_fechacreacion, 'DD/MM/YYYY HH24:MI:SS') INTO V_FechaCreacion FROM DUAL;
 IF CODIGOHOGAR > 0 THEN

     SELECT COUNT(T.IDUSUARIO) INTO V_idpersona FROM ADMINUSUARIOS.USUARIO@DBLINK_VIVANTO T
     WHERE UPPER(T.USUARIOINGRESO) = UPPER(P_usu_usuariocreacion);   
   IF V_idpersona > 0 then
     SELECT T.IDUSUARIO INTO V_idpersona FROM ADMINUSUARIOS.USUARIO@DBLINK_VIVANTO T
     WHERE UPPER(T.USUARIOINGRESO) = UPPER(P_usu_usuariocreacion);
    
   ELSE
     V_idpersona := 0;
   END IF;

   SELECT T.hog_codigo INTO HOGAR FROM gic_hogar T WHERE T.hog_codigoENCUESTA = UPPER(p_P_hog_codigo);
   SELECT COUNT(*) INTO V_cidpersona FROM GIC_MIEMBROS_HOGAR H WHERE H.HOG_CODIGO = HOGAR
   /*AND H.PER_IDPERSONA =  P_Per_Idpersona*/ AND H.IDPERSONA_ENCUMO = P_idpersona_encomu;

   IF V_cidpersona = 0 THEN
     INSERT INTO gic_miembros_hogar VALUES(HOGAR,P_Per_Idpersona,UPPER(P_usu_usuariocreacion),V_idpersona,
     V_FechaCreacion,UPPER(P_per_encuestada),P_idpersona_encomu);
     COMMIT;
     V_SALIDA := 'Insercion ok en gic_miembros_hogar';
   ELSE
     SELECT COUNT(H.PER_IDPERSONA) INTO V_cidpersona FROM GIC_MIEMBROS_HOGAR H WHERE H.HOG_CODIGO = HOGAR
     AND H.PER_IDPERSONA =  P_Per_Idpersona AND H.IDPERSONA_ENCUMO = P_idpersona_encomu;
     V_SALIDA := 'Persona ya existe en gic_miembros_hogar con idpersona:' || V_cidpersona;
   END IF;


 ELSE
    V_SALIDA := 'Hogar no, no se inserto en gic_miembros_hogar';
 END IF;


  EXCEPTION
  WHEN OTHERS THEN
    V_SALIDA := 'Excepción, Error al insertar en gic_miembros_hogar';
    SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'PKG_GESTION_ENCUESTADORMOVIL.GIC_AGREGAR_MIEMBROSHOGAR',p_P_hog_codigo);
    SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'PKG_GESTION_ENCUESTADORMOVIL.GIC_AGREGAR_MIEMBROSHOGAR',p_P_hog_codigo);

END GIC_AGREGAR_MIEMBROSHOGAR;

PROCEDURE GIC_AGREGAR_RESPUESTAENCUESTA(P_hog_codigo NVARCHAR2,P_Per_Idpersona NUMBER,P_Res_IdRespuesta NUMBER,P_Tipo_Pregunta NVARCHAR2,
  P_Usu_Usuariocreacion NVARCHAR2,P_Usu_FechaCreacion NVARCHAR2,P_Ins_Idinstrumento NUMBER,P_Rxp_TextoRespuesta NVARCHAR2,V_SALIDA OUT NVARCHAR2)
AS

FechaCreacion DATE;
CODIGOHOGAR NUMBER;
HOGAR NVARCHAR2(5);
V_IDPERSONA_ENCUMO NUMBER;
RESULTADO VARCHAR2(20);

BEGIN

    SELECT COUNT(T.hog_codigo) INTO CODIGOHOGAR FROM gic_hogar T WHERE UPPER(T.hog_codigoENCUESTA) = UPPER(P_hog_codigo);
    SELECT TO_DATE(P_Usu_FechaCreacion, 'DD/MM/YYYY HH24:MI:SS') INTO FechaCreacion FROM DUAL;

    IF CODIGOHOGAR > 0 THEN
    SELECT T.hog_codigo INTO HOGAR FROM gic_hogar T WHERE T.hog_codigoENCUESTA = UPPER(P_hog_codigo);
    SELECT COUNT(T.PER_IDPERSONA) INTO V_IDPERSONA_ENCUMO FROM GIC_MIEMBROS_HOGAR T WHERE T.IDPERSONA_ENCUMO = P_Per_Idpersona
    AND UPPER(T.HOG_CODIGO) =  UPPER(HOGAR);
        IF V_IDPERSONA_ENCUMO = 0 THEN
          V_SALIDA := 'Persona no existe';
        ELSE
        SELECT T.PER_IDPERSONA INTO V_IDPERSONA_ENCUMO FROM GIC_MIEMBROS_HOGAR T WHERE T.IDPERSONA_ENCUMO = P_Per_Idpersona
        AND UPPER(T.HOG_CODIGO) =  UPPER(HOGAR);
        INSERT INTO GIC_N_RESPUESTASENCUESTA
       (HOG_CODIGO,PER_IDPERSONA,RES_IDRESPUESTA,RXP_TIPOPREGUNTA,USU_USUARIOCREACION,USU_FECHACREACION,INS_IDINSTRUMENTO,RXP_TEXTORESPUESTA)
        VALUES
        (UPPER(TRIM(HOGAR)),
        V_IDPERSONA_ENCUMO,
        P_Res_IdRespuesta,
        UPPER(P_Tipo_Pregunta),
        UPPER(P_usu_usuariocreacion),
        FechaCreacion,
        P_Ins_Idinstrumento,
        UPPER(P_Rxp_TextoRespuesta));
        INSERT INTO GIC_N_RESPUESTASENCUESTA_C
        SELECT * FROM GIC_N_RESPUESTASENCUESTA R WHERE R.HOG_CODIGO = HOGAR;
        DELETE GIC_N_RESPUESTASENCUESTA R WHERE R.HOG_CODIGO = HOGAR;
        COMMIT;
        V_SALIDA := 'Insercion ok en GIC_N_RESPUESTASENCUESTA_C';
        END IF;
    ELSE
    V_SALIDA := 'Hogar no existe no se inserto en GIC_N_RESPUESTASENCUESTA';
    END IF;
    --RESULTADO:= FN_CORREGIR_TEXTOS;
    EXCEPTION
    WHEN OTHERS THEN
    V_SALIDA := 'Excepción, Error al insertar en GIC_N_RESPUESTASENCUESTA';

END GIC_AGREGAR_RESPUESTAENCUESTA;


FUNCTION FN_GET_GENERAR_CODIGO_ENCUESTA RETURN VARCHAR2

IS codigo VARCHAR2(6);
Decision VARCHAR(2);
valor VARCHAR2(2);

i INTEGER;
BEGIN
  codigo:=NULL;
  i:=0;
WHILE i < 5
LOOP
  SELECT ROUND(dbms_random.value(0,9),0) INTO Decision FROM DUAL;
  IF Decision <5 THEN
      SELECT ROUND(dbms_random.value(0,9),0) INTO valor  FROM DUAL;
  ELSE
      SELECT dbms_random.string('U', 1) INTO valor FROM DUAL;
  END IF;
  codigo := CONCAT(codigo,valor);
  i:=i+1;
END LOOP;

RETURN CODIGO;

END FN_GET_GENERAR_CODIGO_ENCUESTA;

FUNCTION FN_GET_CODIGOENCUESTA RETURN VARCHAR2
IS Result VARCHAR2(20);
  Codigo VARCHAR2(20);
  i NUMBER;
  Existe NUMBER;
BEGIN
  i:=1;
  WHILE i = 1
  LOOP
    Codigo := FN_GET_GENERAR_CODIGO_ENCUESTA;
    SELECT count(hog_codigoENCUESTA) INTO Existe
    FROM GIC_HOGAR
    WHERE hog_codigoENCUESTA=Codigo;
    IF Existe = 0 THEN
      i:=0;
    END IF;
  END LOOP;
  Result := Codigo;
  RETURN Result;
END FN_GET_CODIGOENCUESTA;

/*
FUNCTION GET_CODIGOHOGAR
  (
    USUA_CREACION IN NVARCHAR2,
    ID_USUARIO IN INTEGER
  )
  RETURN VARCHAR2
IS Result VARCHAR2(20);
  CODIGOENCUESTA VARCHAR2(20);
  BEGIN

    CODIGOENCUESTA := FN_GET_CODIGOENCUESTA;

    INSERT INTO GIC_HOGAR VALUES(0,TRIM(CODIGOENCUESTA),USUA_CREACION,ID_USUARIO,SYSDATE,2,CODIGOENCUESTA,'MANUAL',SYSDATE,USUA_CREACION);
    COMMIT;
 Result := CODIGOENCUESTA;
 return  Result;
  END;*/
  
 FUNCTION FN_CORREGIR_TEXTOS RETURN VARCHAR2
IS Result VARCHAR2(20);
  Codigo VARCHAR2(20);
  i NUMBER;
  Existe NUMBER;

  CURSOR C1 IS  
  SELECT DISTINCT c.res_idrespuesta from gic_n_respuestasencuesta_c c
  WHERE c.rxp_textorespuesta LIKE '%Ã‘%' ORDER BY C.RES_IDRESPUESTA;

  BEGIN
  FOR v_reg in C1 LOOP
  update gic_n_respuestasencuesta_c f 
  set f.rxp_textorespuesta = 
  (select replace(c.rxp_textorespuesta,'Ã‘','Ñ') from gic_n_respuestasencuesta_c c where c.hog_codigo=f.hog_codigo and c.per_idpersona=f.per_idpersona
  and c.res_idrespuesta=f.res_idrespuesta and c.usu_usuariocreacion=f.usu_usuariocreacion and c.usu_fechacreacion=f.usu_fechacreacion
  and c.rxp_textorespuesta LIKE '%Ã‘%' and c.rxp_idrespuestaxpersona=f.rxp_idrespuestaxpersona and c.res_idrespuesta = v_reg.res_idrespuesta) 
  where f.rxp_textorespuesta LIKE '%Ã‘%' and f.res_idrespuesta = v_reg.res_idrespuesta ;
  COMMIT;
  END LOOP;
  
  Result := 1;
  
  RETURN Result;
END FN_CORREGIR_TEXTOS;



PROCEDURE GIC_N_BORRAR_RES_DUP  AS

BEGIN

--ELIMINA RESPUESTAS DUPLICADAS
DELETE GIC_N_RESPUESTASENCUESTA_C TR WHERE TR.RXP_IDRESPUESTAXPERSONA IN
(
select C.RXP_IDRESPUESTAXPERSONA/*c.*, rowid*/ from gic_n_respuestasencuesta_c c where c.rxp_idrespuestaxpersona in (
select rxp_idrespuestaxpersona from 
(  
select g.*, row_number() over (partition by per_idpersona,res_idrespuesta order by 1 desc) n from gic_n_respuestasencuesta_c g where g.res_idrespuesta in (
   select f.res_idrespuesta from
   (select MH.hog_codigo, mh.per_idpersona, mh.res_idrespuesta, mh.rxp_tipopregunta, mh.usu_usuariocreacion, mh.usu_usuariocreacion,
   mh.ins_idinstrumento, mh.rxp_textorespuesta, count(mh.res_idrespuesta) total
   from gic_n_respuestasencuesta_c mh where mh.hog_codigo IN (select distinct hog_codigo from (
select c.hog_codigo, per_idpersona, res_idrespuesta, c.rxp_tipopregunta, c.usu_usuariocreacion, c.usu_fechacreacion,
c.ins_idinstrumento, c.rxp_textorespuesta, count(c.res_idrespuesta) total from gic_n_respuestasencuesta_c c where c.res_idrespuesta = 1
group by c.hog_codigo, per_idpersona, res_idrespuesta, c.rxp_tipopregunta, c.usu_usuariocreacion, c.usu_fechacreacion,
c.ins_idinstrumento, c.rxp_textorespuesta order by total desc) where total > 1) group by
   MH.hog_codigo, mh.per_idpersona, mh.res_idrespuesta, mh.rxp_tipopregunta, mh.usu_usuariocreacion, mh.usu_usuariocreacion,
   mh.ins_idinstrumento, mh.rxp_textorespuesta having count(mh.res_idrespuesta) > 1 order by 3,2)f)
   and g.hog_codigo IN (select distinct hog_codigo from (
select c.hog_codigo, per_idpersona, res_idrespuesta, c.rxp_tipopregunta, c.usu_usuariocreacion, c.usu_fechacreacion,
c.ins_idinstrumento, c.rxp_textorespuesta, count(c.res_idrespuesta) total from gic_n_respuestasencuesta_c c where c.res_idrespuesta = 1
group by c.hog_codigo, per_idpersona, res_idrespuesta, c.rxp_tipopregunta, c.usu_usuariocreacion, c.usu_fechacreacion,
c.ins_idinstrumento, c.rxp_textorespuesta order by total desc) where total > 1) order by 4,3
   ) where n <> 1) 
   );
COMMIT;
   --order by 4,3;


--ELIMINA CAPITULOS DUPLICADOS
DELETE GIC_N_CAPITULOS_TER TY WHERE TY.ROWID IN
(
SELECT /*T.*, */ROWID FROM GIC_N_CAPITULOS_TER T WHERE T.ROWID IN (         
SELECT ROWID FROM (          
select g.*, row_number() over (partition by HOG_CODIGO,TEM_IDTEMA order by 1 desc) n, ROWID from gic_n_capitulos_ter g where g.tem_idtema in (
(SELECT TEM_IDTEMA FROM(
select ct.HOG_CODIGO, CT.USU_USUARIOCREACION, CT.TEM_IDTEMA, COUNT(CT.TEM_IDTEMA)  TOTAL from gic_n_capitulos_ter ct
where   ct.tem_idtema in (1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40) 
GROUP BY  ct.HOG_CODIGO, CT.USU_USUARIOCREACION, CT.TEM_IDTEMA
HAVING COUNT(CT.TEM_IDTEMA)>1)))
)WHERE  N <> 1)
);
COMMIT;
--ORDER BY 1,2

--BORRAR TIPODOCUMENTO DUPLICADO
DELETE GIC_N_RESPUESTASENCUESTA_C CY WHERE CY.ROWID IN
(
select /*b.*,*/ rowid from gic_n_respuestasencuesta_c b where b.rxp_idrespuestaxpersona in(
select f.rxp_idrespuestaxpersona from (
select g.*, row_number() over (partition by HOG_CODIGO,PER_IDPERSONA order by 1 desc) n, ROWID from GIC_N_RESPUESTASENCUESTA_C g where g.Hog_Codigo in (
SELECT HOG_CODIGO FROM GIC_N_RESPUESTASENCUESTA_C Y WHERE Y.HOG_CODIGO IN (
SELECT HOG_CODIGO FROM (
SELECT C.HOG_CODIGO, C.PER_IDPERSONA, COUNT(C.RES_IDRESPUESTA) TOTAL FROM GIC_N_RESPUESTASENCUESTA_C C WHERE C.RES_IDRESPUESTA IN
(93,94,95,96,97,98,99,100) /*AND C.HOG_CODIGO 
IN (SELECT T.* FROM HOGARES_PRUEBA T)*/ GROUP BY C.HOG_CODIGO, C.PER_IDPERSONA 
) X WHERE X.TOTAL > 1
) AND Y.RES_IDRESPUESTA IN (93,94,95,96,97,98,99,100)
) AND g.res_idrespuesta in (93,94,95,96,97,98,99,100)
) f where f.n > 1
)
);
COMMIT;




--BORRAR PARENTESCO DUPLICADO
DELETE GIC_N_RESPUESTASENCUESTA_C L WHERE L.RXP_IDRESPUESTAXPERSONA IN (
select b.rxp_idrespuestaxpersona from gic_n_respuestasencuesta_c b where b.rxp_idrespuestaxpersona in(
select f.rxp_idrespuestaxpersona from (
select g.*, row_number() over (partition by HOG_CODIGO,PER_IDPERSONA order by 1 desc) n, ROWID from GIC_N_RESPUESTASENCUESTA_C g where g.Hog_Codigo in (
SELECT HOG_CODIGO FROM GIC_N_RESPUESTASENCUESTA_C Y WHERE Y.HOG_CODIGO IN (
SELECT HOG_CODIGO FROM (
SELECT C.HOG_CODIGO, C.PER_IDPERSONA, COUNT(C.RES_IDRESPUESTA) TOTAL FROM GIC_N_RESPUESTASENCUESTA_C C WHERE C.RES_IDRESPUESTA IN
(79,80,81,83,84,906,907,908,909,910,911,912,916) /*AND C.HOG_CODIGO 
IN (SELECT T.* FROM HOGARES_PRUEBA T)*/ GROUP BY C.HOG_CODIGO, C.PER_IDPERSONA 
) X WHERE X.TOTAL > 1
) AND Y.RES_IDRESPUESTA IN (79,80,81,83,84,906,907,908,909,910,911,912,916)
) AND g.res_idrespuesta in (79,80,81,83,84,906,907,908,909,910,911,912,916)
) f where f.n > 1
));
COMMIT;


--BORRAR PISOS DUPLICADO
DELETE GIC_N_RESPUESTASENCUESTA_C L WHERE L.RXP_IDRESPUESTAXPERSONA IN (
select b.rxp_idrespuestaxpersona/*b.*, rowid*/ from gic_n_respuestasencuesta_c b where b.rxp_idrespuestaxpersona in(
select f.rxp_idrespuestaxpersona from (
select g.*, row_number() over (partition by HOG_CODIGO,PER_IDPERSONA order by 1 desc) n, ROWID from GIC_N_RESPUESTASENCUESTA_C g where g.Hog_Codigo in (
SELECT HOG_CODIGO FROM GIC_N_RESPUESTASENCUESTA_C Y WHERE Y.HOG_CODIGO IN (
SELECT HOG_CODIGO FROM (
SELECT C.HOG_CODIGO, C.PER_IDPERSONA, COUNT(C.RES_IDRESPUESTA) TOTAL FROM GIC_N_RESPUESTASENCUESTA_C C WHERE C.RES_IDRESPUESTA IN
(132,133,134,135,136,137,138) /*AND C.HOG_CODIGO 
IN (SELECT T.* FROM HOGARES_PRUEBA T)*/ GROUP BY C.HOG_CODIGO, C.PER_IDPERSONA 
) X WHERE X.TOTAL > 1
) AND Y.RES_IDRESPUESTA IN (132,133,134,135,136,137,138)
) AND g.res_idrespuesta in (132,133,134,135,136,137,138)
) f where f.n > 1
)
);
COMMIT;

--BORRAR ZONA DE RESIDENCIA DUPLICADO
DELETE GIC_N_RESPUESTASENCUESTA_C L WHERE L.RXP_IDRESPUESTAXPERSONA IN (
select b.rxp_idrespuestaxpersona/*b.*, rowid*/ from gic_n_respuestasencuesta_c b where b.rxp_idrespuestaxpersona in(
select f.rxp_idrespuestaxpersona from (
select g.*, row_number() over (partition by HOG_CODIGO,PER_IDPERSONA order by 1 desc) n, ROWID from GIC_N_RESPUESTASENCUESTA_C g where g.Hog_Codigo in (
SELECT HOG_CODIGO FROM GIC_N_RESPUESTASENCUESTA_C Y WHERE Y.HOG_CODIGO IN (
SELECT HOG_CODIGO FROM (
SELECT C.HOG_CODIGO, C.PER_IDPERSONA, COUNT(C.RES_IDRESPUESTA) TOTAL FROM GIC_N_RESPUESTASENCUESTA_C C WHERE C.RES_IDRESPUESTA IN
(8,9,10,966,967,1316) /*AND C.HOG_CODIGO 
IN (SELECT T.* FROM HOGARES_PRUEBA T)*/ GROUP BY C.HOG_CODIGO, C.PER_IDPERSONA 
) X WHERE X.TOTAL > 1
) AND Y.RES_IDRESPUESTA IN (8,9,10,966,967,1316)
) AND g.res_idrespuesta in (8,9,10,966,967,1316)
) f where f.n > 1
)
);
COMMIT;



--BORRAR PAREDES DUPLICADO
DELETE GIC_N_RESPUESTASENCUESTA_C L WHERE L.RXP_IDRESPUESTAXPERSONA IN (
select b.rxp_idrespuestaxpersona/*b.*, rowid*/ from gic_n_respuestasencuesta_c b where b.rxp_idrespuestaxpersona in(
select f.rxp_idrespuestaxpersona from (
select g.*, row_number() over (partition by HOG_CODIGO,PER_IDPERSONA order by 1 desc) n, ROWID from GIC_N_RESPUESTASENCUESTA_C g where g.Hog_Codigo in (
SELECT HOG_CODIGO FROM GIC_N_RESPUESTASENCUESTA_C Y WHERE Y.HOG_CODIGO IN (
SELECT HOG_CODIGO FROM (
SELECT C.HOG_CODIGO, C.PER_IDPERSONA, COUNT(C.RES_IDRESPUESTA) TOTAL FROM GIC_N_RESPUESTASENCUESTA_C C WHERE C.RES_IDRESPUESTA IN
(123,124,125,126,127,128,129,130,131,1065,1066,1067,1323) /*AND C.HOG_CODIGO 
IN (SELECT T.* FROM HOGARES_PRUEBA T)*/ GROUP BY C.HOG_CODIGO, C.PER_IDPERSONA 
) X WHERE X.TOTAL > 1
) AND Y.RES_IDRESPUESTA IN (123,124,125,126,127,128,129,130,131,1065,1066,1067,1323)
) AND g.res_idrespuesta in (123,124,125,126,127,128,129,130,131,1065,1066,1067,1323)
) f where f.n > 1
)
);
COMMIT;


--BORRAR Bienestarina DUPLICADO
DELETE GIC_N_RESPUESTASENCUESTA_C L WHERE L.RXP_IDRESPUESTAXPERSONA IN (
select b.rxp_idrespuestaxpersona/*b.*, rowid*/ from gic_n_respuestasencuesta_c b where b.rxp_idrespuestaxpersona in(
select f.rxp_idrespuestaxpersona from (
select g.*, row_number() over (partition by HOG_CODIGO,PER_IDPERSONA order by 1 desc) n, ROWID from GIC_N_RESPUESTASENCUESTA_C g where g.Hog_Codigo in (
SELECT HOG_CODIGO FROM GIC_N_RESPUESTASENCUESTA_C Y WHERE Y.HOG_CODIGO IN (
SELECT HOG_CODIGO FROM (
SELECT C.HOG_CODIGO, C.PER_IDPERSONA, COUNT(C.RES_IDRESPUESTA) TOTAL FROM GIC_N_RESPUESTASENCUESTA_C C WHERE C.RES_IDRESPUESTA IN
(985,986) /*AND C.HOG_CODIGO 
IN (SELECT T.* FROM HOGARES_PRUEBA T)*/ GROUP BY C.HOG_CODIGO, C.PER_IDPERSONA 
) X WHERE X.TOTAL > 1
) AND Y.RES_IDRESPUESTA IN (985,986)
) AND g.res_idrespuesta in (985,986)
) f where f.n > 1
)
);
COMMIT;


--BORRAR VARIOS DUPLICADO
DELETE GIC_N_RESPUESTASENCUESTA_C L WHERE L.RXP_IDRESPUESTAXPERSONA IN (
select b.rxp_idrespuestaxpersona/*b.*, rowid*/ from gic_n_respuestasencuesta_c b where b.rxp_idrespuestaxpersona in(
select f.rxp_idrespuestaxpersona from (
select g.*, row_number() over (partition by HOG_CODIGO,PER_IDPERSONA order by 1 desc) n, ROWID from GIC_N_RESPUESTASENCUESTA_C g where g.Hog_Codigo in (
SELECT HOG_CODIGO FROM GIC_N_RESPUESTASENCUESTA_C Y WHERE Y.HOG_CODIGO IN (
SELECT HOG_CODIGO FROM (
SELECT C.HOG_CODIGO, C.PER_IDPERSONA, COUNT(C.RES_IDRESPUESTA) TOTAL FROM GIC_N_RESPUESTASENCUESTA_C C WHERE C.RES_IDRESPUESTA IN
(184,185,186,187,188,189) /*AND C.HOG_CODIGO 
IN (SELECT T.* FROM HOGARES_PRUEBA T)*/ GROUP BY C.HOG_CODIGO, C.PER_IDPERSONA 
) X WHERE X.TOTAL > 1
) AND Y.RES_IDRESPUESTA IN (184,185,186,187,188,189)
) AND g.res_idrespuesta in (184,185,186,187,188,189)
) f where f.n > 1
)
);
COMMIT;

--BORRAR RESPUETAS DE PREGUNTA 66 DUPLICADO
DELETE GIC_N_RESPUESTASENCUESTA_C L WHERE L.RXP_IDRESPUESTAXPERSONA IN (
select b.rxp_idrespuestaxpersona/*b.*, rowid*/ from gic_n_respuestasencuesta_c b where b.rxp_idrespuestaxpersona in(
select f.rxp_idrespuestaxpersona from (
select g.*, row_number() over (partition by HOG_CODIGO,PER_IDPERSONA order by 1 desc) n, ROWID from GIC_N_RESPUESTASENCUESTA_C g where g.Hog_Codigo in (
SELECT HOG_CODIGO FROM GIC_N_RESPUESTASENCUESTA_C Y WHERE Y.HOG_CODIGO IN (
SELECT HOG_CODIGO FROM (
SELECT C.HOG_CODIGO, C.PER_IDPERSONA, COUNT(C.RES_IDRESPUESTA) TOTAL FROM GIC_N_RESPUESTASENCUESTA_C C WHERE C.RES_IDRESPUESTA IN
(236,237) /*AND C.HOG_CODIGO 
IN (SELECT T.* FROM HOGARES_PRUEBA T)*/ GROUP BY C.HOG_CODIGO, C.PER_IDPERSONA 
) X WHERE X.TOTAL > 1
) AND Y.RES_IDRESPUESTA IN (236,237)
) AND g.res_idrespuesta in (236,237)
) f where f.n > 1
)
);
COMMIT;

--BORRAR RESPUETAS DE PREGUNTA 67 DUPLICADO
DELETE GIC_N_RESPUESTASENCUESTA_C L WHERE L.RXP_IDRESPUESTAXPERSONA IN (
select b.rxp_idrespuestaxpersona/*b.*, rowid*/ from gic_n_respuestasencuesta_c b where b.rxp_idrespuestaxpersona in(
select f.rxp_idrespuestaxpersona from (
select g.*, row_number() over (partition by HOG_CODIGO,PER_IDPERSONA order by 1 desc) n, ROWID from GIC_N_RESPUESTASENCUESTA_C g where g.Hog_Codigo in (
SELECT HOG_CODIGO FROM GIC_N_RESPUESTASENCUESTA_C Y WHERE Y.HOG_CODIGO IN (
SELECT HOG_CODIGO FROM (
SELECT C.HOG_CODIGO, C.PER_IDPERSONA, COUNT(C.RES_IDRESPUESTA) TOTAL FROM GIC_N_RESPUESTASENCUESTA_C C WHERE C.RES_IDRESPUESTA IN
(238,239) /*AND C.HOG_CODIGO 
IN (SELECT T.* FROM HOGARES_PRUEBA T)*/ GROUP BY C.HOG_CODIGO, C.PER_IDPERSONA 
) X WHERE X.TOTAL > 1
) AND Y.RES_IDRESPUESTA IN (238,239)
) AND g.res_idrespuesta in (238,239)
) f where f.n > 1
)
);
COMMIT;


--BORRAR RESPUETAS DE PREGUNTA 68 DUPLICADO
DELETE GIC_N_RESPUESTASENCUESTA_C L WHERE L.RXP_IDRESPUESTAXPERSONA IN (
select b.rxp_idrespuestaxpersona/*b.*, rowid*/ from gic_n_respuestasencuesta_c b where b.rxp_idrespuestaxpersona in(
select f.rxp_idrespuestaxpersona from (
select g.*, row_number() over (partition by HOG_CODIGO,PER_IDPERSONA order by 1 desc) n, ROWID from GIC_N_RESPUESTASENCUESTA_C g where g.Hog_Codigo in (
SELECT HOG_CODIGO FROM GIC_N_RESPUESTASENCUESTA_C Y WHERE Y.HOG_CODIGO IN (
SELECT HOG_CODIGO FROM (
SELECT C.HOG_CODIGO, C.PER_IDPERSONA, COUNT(C.RES_IDRESPUESTA) TOTAL FROM GIC_N_RESPUESTASENCUESTA_C C WHERE C.RES_IDRESPUESTA IN
(240,241) /*AND C.HOG_CODIGO 
IN (SELECT T.* FROM HOGARES_PRUEBA T)*/ GROUP BY C.HOG_CODIGO, C.PER_IDPERSONA 
) X WHERE X.TOTAL > 1
) AND Y.RES_IDRESPUESTA IN (240,241)
) AND g.res_idrespuesta in (240,241)
) f where f.n > 1
)
);
COMMIT;

--BORRAR RESPUETAS DE PREGUNTA 69 DUPLICADO
DELETE GIC_N_RESPUESTASENCUESTA_C L WHERE L.RXP_IDRESPUESTAXPERSONA IN (
select b.rxp_idrespuestaxpersona/*b.*, rowid*/ from gic_n_respuestasencuesta_c b where b.rxp_idrespuestaxpersona in(
select f.rxp_idrespuestaxpersona from (
select g.*, row_number() over (partition by HOG_CODIGO,PER_IDPERSONA order by 1 desc) n, ROWID from GIC_N_RESPUESTASENCUESTA_C g where g.Hog_Codigo in (
SELECT HOG_CODIGO FROM GIC_N_RESPUESTASENCUESTA_C Y WHERE Y.HOG_CODIGO IN (
SELECT HOG_CODIGO FROM (
SELECT C.HOG_CODIGO, C.PER_IDPERSONA, COUNT(C.RES_IDRESPUESTA) TOTAL FROM GIC_N_RESPUESTASENCUESTA_C C WHERE C.RES_IDRESPUESTA IN
(242,243) /*AND C.HOG_CODIGO 
IN (SELECT T.* FROM HOGARES_PRUEBA T)*/ GROUP BY C.HOG_CODIGO, C.PER_IDPERSONA 
) X WHERE X.TOTAL > 1
) AND Y.RES_IDRESPUESTA IN (242,243)
) AND g.res_idrespuesta in (242,243)
) f where f.n > 1
)
);
COMMIT;


--BORRAR DUPLICADOS MIEMBROS HOGAR
DELETE GIC_MIEMBROS_HOGAR MH WHERE MH.ROWID IN (
select /*i.*,*/ rowid from GIC_MIEMBROS_HOGAR i where i.rowid in (
select  rowid from (
select g.*, row_number() over (partition by HOG_CODIGO, per_idpersona order by 1 desc) n, ROWID from GIC_MIEMBROS_HOGAR g where g.Hog_Codigo in (
SELECT HOG_CODIGO FROM 
(
SELECT HOG_CODIGO, PER_IDPERSONA, COUNT(PER_IDPERSONA) TOTAL FROM GIC_MIEMBROS_HOGAR GROUP BY HOG_CODIGO, PER_IDPERSONA
) F WHERE F.TOTAL > 1
)
) x where x.n <> 1
)
);
COMMIT;

BEGIN 

FOR CUR_ACT IN (
SELECT RESP.HOG_CODIGO,RESP.RES_IDRESPUESTA, RESP.PER_IDPERSONA, COUNT(*), MIN(RESP.RXP_IDRESPUESTAXPERSONA) MEN_ID
FROM   GIC_N_RESPUESTASENCUESTA_C RESP --WHERE RESP.HOG_CODIGO = '6WG63'
GROUP BY  RESP.HOG_CODIGO,RESP.RES_IDRESPUESTA, RESP.PER_IDPERSONA
HAVING COUNT(*)>1
) LOOP

DELETE GIC_N_RESPUESTASENCUESTA_C C 
WHERE C.HOG_CODIGO=CUR_ACT.HOG_CODIGO
AND C.RES_IDRESPUESTA=CUR_ACT.RES_IDRESPUESTA
AND C.PER_IDPERSONA=CUR_ACT.PER_IDPERSONA
AND C.RXP_IDRESPUESTAXPERSONA<>CUR_ACT.MEN_ID;

COMMIT;

END LOOP;
END;


END GIC_N_BORRAR_RES_DUP;



END PKG_GESTION_ENCUESTADORMOVIL;

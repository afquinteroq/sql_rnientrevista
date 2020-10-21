CREATE OR REPLACE PACKAGE BODY GIC_N_CARACTERIZACION IS

--INSERTA LAS RESPUESTAS DE LA ENCUESTA
PROCEDURE SP_SET_RESPUESTAS_DE_ENCUESTA
(
pcod_hogar in varchar2,
pper_IdPersona in NUMBER,
pres_IdRespuesta in NUMBER,
prxp_TextoRespuesta in varchar2,
prxp_TipoPreguntaRespuesta in varchar2,
pins_IdInstrumento in number,
pusu_UsuarioCreacion in varchar2,
pper_idPreguntaPadre in number,
pbANDera in number
)

AS
pValidador NUMBER;
textVal varchar2(500);
pOrden NUMBER;
BEGIN

SELECT PR.IXP_ORDEN INTO pOrden FROM GIC_N_INSTRUMENTOXPREG PR
JOIN GIC_N_RESPUESTAS RE ON RE.PRE_IDPREGUNTA= PR.PRE_IDPREGUNTA
WHERE RE.RES_IDRESPUESTA=pres_IdRespuesta;
--Comprueba el validador y lo carga
  SELECT COALESCE(VAL_IDVALIDADOR,0),  VAL_IDVALIDADOR_DEF into pValidador, textVal
  FROM GIC_N_INSTRUMENTOXRESP WHERE
  RES_IDRESPUESTA=pres_IdRespuesta;
--verIFica si la respuesta cambio

 IF FN_VERIFICARRESPUESTA(pcod_hogar,pins_IdInstrumento,pres_IdRespuesta,pper_IdPersona,prxp_TextoRespuesta) = FALSE OR pOrden=1  THEN
    IF pbANDera = 1 THEN
       GIC_N_CARACTERIZACION.SP_BORRADORESPUESTAS(pcod_hogar => pcod_hogar,
                                                  pins_idinstrumento => pins_IdInstrumento,
                                                  pID_RESPUESTA => pper_idPreguntaPadre,
                                                  pper_IdPersona => pper_IdPersona
                                                  );

    END IF;
    

    
    INSERT INTO GIC_N_RESPUESTASENCUESTA
    (HOG_CODIGO, PER_IDPERSONA, RES_IDRESPUESTA, RXP_TIPOPREGUNTA, USU_USUARIOCREACION,  INS_IDINSTRUMENTO, RXP_TEXTORESPUESTA)
    VALUES
    (pcod_hogar,pper_IdPersona,pres_IdRespuesta,prxp_TipoPreguntaRespuesta,pusu_UsuarioCreacion,pins_IdInstrumento,prxp_TextoRespuesta);
    COMMIT;
 END IF;
 IF pbANDera = 1 THEN
   --SE ADICIONA PARA REALIZAR EL BORRADO DE LOS VALIDADORES
       GIC_N_CARACTERIZACION.SP_BORRADOVALIDADORES(pcod_hogar => pcod_hogar,
                                                  pins_idinstrumento => pins_IdInstrumento,
                                                  pId_Pregunta => pper_idPreguntaPadre,
                                                  pper_IdPersona => pper_IdPersona
                                                  );
 END IF;
--pValidador := FN_COMPROBARVALIDACION(pres_IdRespuesta);


  IF pValidador <> 0 THEN

    IF textVal is null then
      INSERT INTO GIC_N_VALIDADORESXPERSONA(INS_IDINSTRUMENTO,PER_IDPERSONA,  VAL_IDVALIDADOR,  PRE_VALOR,  HOG_CODIGO)
      VALUES(pins_IdInstrumento,pper_IdPersona,pValidador,prxp_TextoRespuesta,pcod_hogar);
    ELSE
      INSERT INTO GIC_N_VALIDADORESXPERSONA(INS_IDINSTRUMENTO,PER_IDPERSONA,  VAL_IDVALIDADOR,  PRE_VALOR,  HOG_CODIGO)
      VALUES(pins_IdInstrumento,pper_IdPersona,pValidador,textVal,pcod_hogar);
    end IF;
    COMMIT;
    
  END IF;
  
  SP_INS_ETNIA_ARES(pcod_hogar);
  
--CAMBIA EL ESTADO EN LA TABLA GIC_N_PREGUNTASDERIVADAS A 1
   gic_n_caracterizacion.sp_cambiar_estadoguardado(phog_codigo => pcod_hogar,
                                                  pins_idinstrumento => pins_IdInstrumento,
                                                  pper_idpersona => pper_IdPersona,
                                                  pres_idrespuesta => pper_idPreguntaPadre);
--INSERTA LAS PREGUNTAS DE LA PREGUNTA QUE INGRESA
    gic_n_caracterizacion.SP_SET_PREGUNTAS_DERIVADAS(phog_codigo => pcod_hogar,
                                                  pper_idpersona => pper_IdPersona,
                                                  pins_idinstrumento => pins_IdInstrumento,
                                                  pId_RespuestaEncuesta => pres_IdRespuesta,
                                                  pId_PreguntaPadre => pper_idPreguntaPadre );
                                                  


 Exception  when others then
        SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_SET_RESPUESTAS_DE_ENCUESTA',pcod_hogar);
        SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_SET_RESPUESTAS_DE_ENCUESTA',pcod_hogar);

END SP_SET_RESPUESTAS_DE_ENCUESTA;

--ELIMINAR RESPUESTAS DE PREGUNTAS FUERA DEL FLUJO
PROCEDURE SP_SET_ELIMINAR_RESP_ENCUESTA
(
pHOG_CODIGO IN VARCHAR2,
pID_TEMA IN NUMBER,
pINS_IDINSTRUMENTO IN NUMBER
)
AS
BEGIN
DELETE FROM GIC_N_RESPUESTASENCUESTA D
WHERE D.RES_IDRESPUESTA IN (
SELECT DISTINCT B.RES_IDRESPUESTA FROM
(SELECT * FROM Gic_n_Instrumentoxpreg U
WHERE U.INS_IDINSTRUMENTO=pINS_IDINSTRUMENTO
AND U.TEM_IDTEMA=pID_TEMA
AND U.PRE_IDPREGUNTA NOT IN (select DISTINCT t.pre_idpregunta from gic_n_preguntasderivadas t WHERE hog_codigo=pHOG_CODIGO AND T.TEM_IDTEMA=pID_TEMA)
AND U.IXP_ORDEN>1) A
LEFT JOIN
GIC_N_RESPUESTAS B
ON A.PRE_IDPREGUNTA=B.PRE_IDPREGUNTA)
AND D.HOG_CODIGO=pHOG_CODIGO
AND D.INS_IDINSTRUMENTO=pINS_IDINSTRUMENTO;
COMMIT;


 Exception  when others then
    SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_SET_ELIMINAR_RESP_ENCUESTA','');
    SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_SET_ELIMINAR_RESP_ENCUESTA','');

END SP_SET_ELIMINAR_RESP_ENCUESTA;

--COMPRUEBA VALDIADOR DE LA PREGUNTA Y TRAE EL ID DEL VALIDADOR
FUNCTION FN_COMPROBARVALIDACION(pIDRESPUESTA in integer) return integer is
  Result integer;

begin

     SELECT   COALESCE(VAL_IDVALIDADOR_DATO,0) INTO RESULT
     FROM GIC_N_INSTRUMENTOXPREG PR
     JOIN GIC_N_RESPUESTAS RE ON RE.PRE_IDPREGUNTA=PR.PRE_IDPREGUNTA
     WHERE RE.RES_IDRESPUESTA=pIDRESPUESTA;
  IF result is null then
   result :=0;
   end IF;
  return(Result);
  
   Exception  when others then
    SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'FN_COMPROBARVALIDACION','');
    SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'FN_COMPROBARVALIDACION','');
    
END FN_COMPROBARVALIDACION;

--Buscar las preguntas derivadas de una respuesta y las guarda en GIC_N_RESPUESTASDERIVADAS
PROCEDURE SP_SET_PREGUNTAS_DERIVADAS
  (
  pHOG_CODIGO IN VARCHAR2,
  pPER_IDPERSONA IN NUMBER,
  pINS_IDINSTRUMENTO IN NUMBER,
  pId_RespuestaEncuesta IN NUMBER,
  pId_PreguntaPadre IN NUMBER
  )
AS
pId_Tema  NUMBER;
pres_finaliza varchar(2);
pTipo_Preg varchar(2);
pTipo_valres number;
pTipo_valfun number;
pTipo_Camp varchar(2);
pTodoHogar number;
pValidador number;
pConteoHogar NUMBER;
pConteo NUMBER;
BEGIN
  

SELECT TEM_IDTEMA INTO pId_Tema FROM GIC_N_INSTRUMENTOXPREG T
WHERE T.PRE_IDPREGUNTA=pId_PreguntaPadre;

--BUSCAR EL TIPO DE PREGUNTA
SELECT T.PRE_TIPOPREGUNTA, T.PRE_TIPOCAMPO
INTO pTipo_Preg, pTipo_Camp
FROM gic_n_instrumentoxpreg t
WHERE
INS_IDINSTRUMENTO=pINS_IDINSTRUMENTO
AND TEM_IDTEMA=pId_Tema
AND PRE_IDPREGUNTA=pId_PreguntaPadre;

--borra todas las preguntas derivadas de la pregunta padre
IF pTipo_Camp <> 'CL' THEN
  DELETE FROM GIC_N_PREGUNTASDERIVADAS PR
  WHERE PR.HOG_CODIGO=pHOG_CODIGO
  AND PR.INS_IDINSTRUMENTO=pINS_IDINSTRUMENTO
  AND PR.PRE_IDPREGUNTAPADRE = pId_PreguntaPadre
  AND PR.PER_IDPERSONA=pPER_IDPERSONA
  AND PR.TEM_IDTEMA =pId_Tema;
END IF;
COMMIT;

SELECT RES_FINALIZA INTO pres_finaliza FROM GIC_N_INSTRUMENTOXRESP T
WHERE RES_IDRESPUESTA IN (pId_RespuestaEncuesta);

IF pres_finaliza = 'SI' THEN
  DELETE  FROM GIC_N_PREGUNTASDERIVADAS  WHERE PER_IDPERSONA=pPER_IDPERSONA
  AND GUARDADO=0;
 COMMIT;
END IF;

IF pTipo_Preg='IN' THEN
  INSERT INTO GIC_N_PREGUNTASDERIVADAS(HOG_CODIGO, PRE_IDPREGUNTA, PER_IDPERSONA, GUARDADO, INS_IDINSTRUMENTO, TEM_IDTEMA,PRE_IDPREGUNTAPADRE)
  SELECT HOG_CODIGO,PRE_IDPREGUNTA,PER_IDPERSONA,GUARDADO, Instrumento,idtema,prepadre FROM
    (SELECT pHOG_CODIGO AS HOG_CODIGO ,PH.PRE_IDPREGUNTA, pPER_IDPERSONA AS PER_IDPERSONA,0 AS GUARDADO, pINS_IDINSTRUMENTO  as Instrumento,(SELECT TEM_IDTEMA  FROM GIC_N_INSTRUMENTOXPREG
         WHERE PRE_IDPREGUNTA=ph.PRE_IDPREGUNTA ) as idtema,pId_PreguntaPadre as prepadre,
   (SELECT DISTINCT PER_ENCUESTADA FROM GIC_MIEMBROS_HOGAR WHERE HOG_CODIGO=pHOG_CODIGO AND PER_IDPERSONA=pPER_IDPERSONA) as encuestada,
  PR.PRE_TIPOPREGUNTA
  FROM GIC_N_PREGUNTAHIJOS PH
  left JOIN GIC_N_INSTRUMENTOXPREG  PR ON PR.PRE_IDPREGUNTA=PH.PRE_IDPREGUNTA AND PR.PRE_ACTIVA='SI'
  WHERE ph.RES_IDRESPUESTA = pId_RespuestaEncuesta)
  WHERE PRE_TIPOPREGUNTA='IN' OR (PRE_TIPOPREGUNTA='GE' AND encuEstada='SI');
ELSIF pTipo_Preg='GE' THEN
  FOR CUR_DATOS IN (SELECT DISTINCT T.PER_IDPERSONA FROM GIC_MIEMBROS_HOGAR t WHERE hog_codigo=pHOG_CODIGO)
  LOOP
      INSERT INTO GIC_N_PREGUNTASDERIVADAS(HOG_CODIGO, PRE_IDPREGUNTA, PER_IDPERSONA, GUARDADO, INS_IDINSTRUMENTO, TEM_IDTEMA,PRE_IDPREGUNTAPADRE)
      SELECT HOG_CODIGO,PRE_IDPREGUNTA,PER_IDPERSONA,GUARDADO, Instrumento,idtema,prepadre FROM
        (SELECT pHOG_CODIGO AS HOG_CODIGO ,PH.PRE_IDPREGUNTA, CUR_DATOS.PER_IDPERSONA AS PER_IDPERSONA,0 AS GUARDADO, pINS_IDINSTRUMENTO  as Instrumento,(SELECT TEM_IDTEMA  FROM GIC_N_INSTRUMENTOXPREG
             WHERE PRE_IDPREGUNTA=ph.PRE_IDPREGUNTA ) as idtema,pId_PreguntaPadre as prepadre,
       (SELECT DISTINCT  PER_ENCUESTADA FROM GIC_MIEMBROS_HOGAR WHERE HOG_CODIGO=pHOG_CODIGO AND PER_IDPERSONA=CUR_DATOS.PER_IDPERSONA) as encuestada,
      PR.PRE_TIPOPREGUNTA
      FROM GIC_N_PREGUNTAHIJOS PH
      left JOIN GIC_N_INSTRUMENTOXPREG  PR ON PR.PRE_IDPREGUNTA=PH.PRE_IDPREGUNTA AND PR.PRE_ACTIVA='SI'
      WHERE ph.RES_IDRESPUESTA = pId_RespuestaEncuesta)
      WHERE PRE_TIPOPREGUNTA='IN' OR (PRE_TIPOPREGUNTA='GE' AND encuEstada='SI');
  END LOOP;
END IF;
COMMIT;

--1. VALIDA QUE EL CAMPO PRE_DEPENDE DE LA TABLA GIC_N_PREGUNTASHIJOS ESTE MARCADO CON LA ETIQUETA 'SI', PARA REALIZAR
--LAS VALIDACIONES QUE HABILITAN LAS PREGUNTAS CONFIGURADAS EN EL CAMPO PRE_IDPREGUNTA DE LA TABLA GIC_N_PREGUNTASHIJOS
SELECT COUNT(t.pre_idpregunta) INTO pTipo_valres FROM gic_n_preguntahijos t
WHERE res_idrespuesta IN (pId_RespuestaEncuesta) AND T.PRE_DEPENDE='SI' ORDER BY PRE_DEPENDE DESC;

--SI LA  VARIABLE pTipo_valres ES MAYOR 0 ENTONCES INGRESA AL PROCEDIMIENTO SP_GET_PREGUNTAS, PARA EJECUTAR
--LA LOGICA DEL PRE_DEPENDE
IF pTipo_valres > 0 THEN
  
GIC_N_CARACTERIZACION.SP_GET_PREGUNTAS(pINS_IDINSTRUMENTO,pHOG_CODIGO,pId_Tema,pPER_IDPERSONA,pId_RespuestaEncuesta,pId_PreguntaPadre,pTipo_valres);
 
--SI LA  VARIABLE pTipo_valres ES  0 ENTONCES TERMINA EL PROCEDIMIENTO
  
END IF;

COMMIT;

Exception  when others then
    SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_SET_PREGUNTAS_DERIVADAS','');
    SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_SET_PREGUNTAS_DERIVADAS','');

END SP_SET_PREGUNTAS_DERIVADAS;

FUNCTION FN_VALIDARPERSONA(VALOR IN VARCHAR2, pVAL_IDVALIDADOR IN NUMBER) RETURN INTEGER IS
  Result integer;
  Val varchar(50);
  Existe NUMBER;
  BEGIN
    Result:=0;
    select PRE_VALIDADOR into Val from GIC_N_INSTRUMENTOXVALIDADOR VP WHERE VP.VAL_IDVALIDADOR=pVAL_IDVALIDADOR;
IF Val = 'NU' then
  select COUNT(PRE_VALIDADOR) INTO Existe from GIC_N_INSTRUMENTOXVALIDADOR VP WHERE VP.VAL_IDVALIDADOR=pVAL_IDVALIDADOR
  AND TO_NUMBER(VALOR) BETWEEN PRE_VALIDADOR_MIN AND PRE_VALIDADOR_MAX;
  IF Existe >0 THEN
    select 1 INTO Result from GIC_N_INSTRUMENTOXVALIDADOR VP WHERE VP.VAL_IDVALIDADOR=pVAL_IDVALIDADOR
    AND TO_NUMBER(VALOR) BETWEEN PRE_VALIDADOR_MIN AND PRE_VALIDADOR_MAX;
  ELSE
    Result:=0;
  END IF;
ELSIF Val = 'FE' then
   select  COUNT(PRE_VALIDADOR) INTO Existe from GIC_N_INSTRUMENTOXVALIDADOR VP WHERE VP.VAL_IDVALIDADOR=pVAL_IDVALIDADOR
  AND TO_DATE(VALOR, 'DD/MM/YYYY') BETWEEN TO_DATE(PRE_VALIDADOR_MIN,'DD/MM/YYYY') AND TO_DATE(PRE_VALIDADOR_MAX,'DD/MM/YYYY');
  IF Existe >0 THEN
     select 1 INTO Result from GIC_N_INSTRUMENTOXVALIDADOR VP WHERE VP.VAL_IDVALIDADOR=pVAL_IDVALIDADOR
  AND TO_DATE(VALOR, 'DD/MM/YYYY') BETWEEN TO_DATE(PRE_VALIDADOR_MIN,'DD/MM/YYYY') AND TO_DATE(PRE_VALIDADOR_MAX,'DD/MM/YYYY');
   ELSE
    Result:=0;
  END IF;

  ELSIF Val = 'TE' OR Val = 'IN'  then
 SELECT COUNT(PRE_VALIDADOR) INTO Existe
 FROM GIC_N_INSTRUMENTOXVALIDADOR VP WHERE VP.VAL_IDVALIDADOR=pVAL_IDVALIDADOR
  AND PRE_VALIDADOR_MIN=VALOR;
  IF Existe >0 THEN
   SELECT 1  INTO Result
   from GIC_N_INSTRUMENTOXVALIDADOR VP WHERE VP.VAL_IDVALIDADOR=pVAL_IDVALIDADOR
  AND PRE_VALIDADOR_MIN=VALOR;
  ELSE
    Result:=0;
  END IF;
end IF;

 return(Result);

      Exception  when others then
      return 0;
      SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'FN_VALIDARPERSONA','');
      SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'FN_VALIDARPERSONA','');
      
END FN_VALIDARPERSONA;

--ELIMINA LA PREGUNTA DERIVADA ANTERIOR
PROCEDURE SP_BORRARPREGUNTASANTERIORES
(
  pHOG_CODIGO IN VARCHAR2,
  pPER_IDPERSONA IN NUMBER,
  pINS_IDINSTRUMENTO IN NUMBER,
  pID_PREGUNTA IN NUMBER
  )
AS
BEGIN
  DELETE FROM  GIC_N_PREGUNTASDERIVADAS  WHERE HOG_CODIGO=pHOG_CODIGO AND PER_IDPERSONA=pPER_IDPERSONA
  AND INS_IDINSTRUMENTO=pINS_IDINSTRUMENTO AND PRE_IDPREGUNTA=pID_PREGUNTA;
  COMMIT;
  
  Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_BORRARPREGUNTASANTERIORES','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_BORRARPREGUNTASANTERIORES','');
  
END   SP_BORRARPREGUNTASANTERIORES;


PROCEDURE SP_BUSCAR_SIGUIENTE_PREGUNTA(
  pHOG_CODIGO IN VARCHAR2,
  pID_TEMA IN NUMBER,
  pINS_IDINSTRUMENTO IN NUMBER,
  pID_PREGUNTA IN NUMBER,
  cur_OUT OUT SYS_REFCURSOR
  )
  AS
  pCont_Preg number;
  MAX_pCont_Preg number;
  finCapitulo number;
  pTotalValidaciones number;
  pConteoValidaciones number;
 -- p_termino number;

  BEGIN
      --NR-2020-05
    SELECT COUNT(1) INTO finCapitulo 
      FROM gic_n_encuesta_ter TD
     WHERE TD.HOG_CODIGO=pHOG_CODIGO;
     
    IF finCapitulo > 0 THEN
       pCont_Preg:=pID_PREGUNTA;
    ELSE
        IF pID_PREGUNTA = 1 THEN           
          --NR-2020-05
          SELECT COALESCE(MIN(pr.ixp_orden),1) INTO pCont_Preg 
            FROM gic_n_preguntasderivadas td,
                 gic_n_instrumentoxpreg pr
           WHERE pr.pre_idpregunta=td.pre_idpregunta 
             AND td.guardado=0 
             AND td.hog_codigo= pHOG_CODIGO
             AND pr.tem_idtema= pID_TEMA;
           
           /*se carga el orden de la ultima pregunta del tema*/
            SELECT MAX(PR.IXP_ORDEN) INTO MAX_pCont_Preg 
              FROM GIC_N_INSTRUMENTOXPREG PR
              WHERE INS_IDINSTRUMENTO=pINS_IDINSTRUMENTO
                AND PR.TEM_IDTEMA=pID_TEMA 
                AND PRE_ACTIVA='SI';
            
        ELSE            
            --NR-2020-05
            SELECT COALESCE(MIN(pr.ixp_orden),0) INTO pCont_Preg 
              FROM gic_n_preguntasderivadas td,
                   gic_n_instrumentoxpreg pr
             WHERE pr.pre_idpregunta=td.pre_idpregunta 
               AND td.guardado=0 
               AND td.hog_codigo= pHOG_CODIGO
               AND pr.tem_idtema= pID_TEMA;
           
           /*se carga la maxima pregunta en preguntas derivadas*/
       
            --NR-2020-05
            SELECT MAX(IXP_ORDEN) INTO MAX_pCont_Preg 
            FROM
             (SELECT t.pre_idpregunta,u.ixp_orden 
                FROM gic_n_preguntasderivadas t,
                     gic_n_instrumentoxpreg u
               WHERE t.pre_idpregunta=u.pre_idpregunta(+)
                 AND hog_codigo= pHOG_CODIGO 
                 AND T.TEM_IDTEMA=pID_TEMA 
                 AND T.INS_IDINSTRUMENTO= pINS_IDINSTRUMENTO
                 AND PRE_ACTIVA='SI' 
                 AND T.GUARDADO=0
             ORDER BY t.pre_idpregunta);                                 
        END IF;
    END IF;

 LOOP
    --SUMATORIA DE VALIDACIONES
      --NR-2020-05
       SELECT
         SUM(gic_n_caracterizacion.fn_comprobarvalidaciones(f.per_idpersona, f.PRE_IDPREGUNTA, pHOG_CODIGO, pINS_IDINSTRUMENTO)) totalValidaciones,
       COUNT(GIC_N_CARACTERIZACION.FN_COMPROBARVALIDACIONES(f.per_idpersona, f.PRE_IDPREGUNTA, pHOG_CODIGO, pINS_IDINSTRUMENTO)) conteoValidaciones 
        INTO pTotalValidaciones,pConteoValidaciones
        FROM (SELECT per_idpersona, i.pre_idpregunta, hog_codigo
                FROM gic_n_instrumentoxpreg i
                JOIN gic_n_preguntas p 
                  ON p.pre_idpregunta = i.pre_idpregunta,
             (SELECT hog_codigo,d.per_idpersona
                FROM gic_miembros_hogar d,
                            gic_persona e
               WHERE d.per_idpersona=e.per_idpersona
                 AND hog_codigo=pHOG_CODIGO)
                WHERE ixp_orden =pCont_Preg
                  AND i.pre_activa='SI'
                  AND i.ins_idinstrumento = pINS_IDINSTRUMENTO
                  AND i.tem_idtema=pID_TEMA
                ) f,
                  gic_n_preguntas g
       WHERE f.PRE_IDPREGUNTA=g.PRE_IDPREGUNTA(+)
       ORDER BY per_idpersona;

      IF pTotalValidaciones =0 AND pConteoValidaciones >0 THEN
          UPDATE gic_n_preguntasderivadas SET GUARDADO=1
          WHERE HOG_CODIGO=pHOG_CODIGO AND pre_idpregunta =(select t.pre_idpregunta from gic_n_instrumentoxpreg t
          WHERE t.ixp_orden=pCont_Preg
          AND T.TEM_IDTEMA=pID_TEMA
          AND PRE_ACTIVA='SI'
          AND T.INS_IDINSTRUMENTO=pINS_IDINSTRUMENTO)
          ;
          IF pID_PREGUNTA = 1 THEN
            --se busca en la siguiente pregunta del tema
            pCont_Preg :=pCont_Preg+1;
          ELSE
            --se busca en la siguiente pregunta derivada                 
            --NR--2020-05
            SELECT MIN(ixp_orden) INTO pCont_Preg 
              FROM (SELECT t.* ,u.ixp_orden
                      FROM gic_n_preguntasderivadas t,
                           gic_n_instrumentoxpreg u     
                    WHERE t.pre_idpregunta=u.pre_idpregunta(+)
                      AND hog_codigo=pHOG_CODIGO 
                      AND t.tem_idtema=pID_TEMA 
                      AND t.ins_idinstrumento=pINS_IDINSTRUMENTO
                      AND pre_activa='SI' 
                      AND GUARDADO=0)                
             WHERE ixp_orden > pCont_Preg;
             
          END IF;
          IF pCont_Preg > MAX_pCont_Preg THEN
             EXIT;
          END IF;
      ELSE
         EXIT ;
      END IF;
  END LOOP;
--ELIMINAR RESPUESTAS DE PREGUNTAS FUERA DEL FLUJO
    gic_n_caracterizacion.SP_SET_ELIMINAR_RESP_ENCUESTA(phog_codigo => pHOG_CODIGO,
                                                  pins_idinstrumento => pINS_IDINSTRUMENTO,
                                                  pid_TEMA => pID_TEMA
                                                  );

-- borra las respuestas de las personas que no validan
delete from gic_n_respuestasencuesta d
WHERE exists
(select a.PER_IDPERSONA, b.res_idrespuesta from(
                        SELECT DISTINCT
                          f.PRE_IDPREGUNTA ,
                          case when pre_tipopregunta='IN' then f.per_idpersona end PER_IDPERSONA ,
                          case when pre_tipopregunta='IN' then GIC_N_CARACTERIZACION.FN_COMPROBARVALIDACIONES(f.per_idpersona, f.PRE_IDPREGUNTA, pHOG_CODIGO, pINS_IDINSTRUMENTO) end validacion_persona
                          from
                          (
                          SELECT i.PRE_IDPREGUNTA,p.pre_pregunta,pre_tipopregunta,  pre_tipocampo, hog_codigo, per_idpersona, per_primernombre,
                          per_segundonombre, per_primerapellido, per_segundoapellido, i.ixp_orden,  PER_FECHANACIMIENTO, PER_NUMERODOC
                          FROM GIC_N_INSTRUMENTOXPREG i
                          JOIN GIC_N_PREGUNTAS p on p.pre_idpregunta = i.pre_idpregunta
                          ,
                          (select hog_codigo, d.per_idpersona, per_primernombre, per_segundonombre, per_primerapellido, per_segundoapellido,
                          PER_FECHANACIMIENTO, PER_NUMERODOC
                          from gic_miembros_hogar d, gic_persona e
                          WHERE d.per_idpersona=e.per_idpersona
                                AND HOG_CODIGO=pHOG_CODIGO
                          )
                        WHERE  IXP_ORDEN =pCont_Preg
                        AND i.PRE_ACTIVA='SI'
                        AND i.INS_IDINSTRUMENTO=pINS_IDINSTRUMENTO
                        AND i.TEM_IDTEMA=pID_TEMA
                          ) f
                          left join gic_n_preguntas g
                          on f.PRE_IDPREGUNTA=g.PRE_IDPREGUNTA
                          ORDER BY PER_IDPERSONA
                        ) A
        LEFT JOIN gic_n_respuestas B
        on (a.PRE_IDPREGUNTA=b.pre_idpregunta)
        WHERE validacion_persona=0
AND d.hog_codigo=pHOG_CODIGO
AND A.PER_IDPERSONA= d.per_idpersona
AND B.res_idrespuesta= d.res_idrespuesta
)
;
COMMIT;


--devuelve siguiente pregunta
    OPEN cur_OUT FOR
        SELECT DISTINCT
        f.PRE_IDPREGUNTA ,
        f.PRE_PREGUNTA,
        f.PRE_TIPOPREGUNTA ,
        f.PRE_TIPOCAMPO,
        f.HOG_CODIGO,
        case when pre_tipopregunta='IN' then f.per_idpersona end PER_IDPERSONA ,
        case when pre_tipopregunta='IN' then f.per_primernombre end per_primernombre ,
        case when pre_tipopregunta='IN' then f.per_segundonombre end per_segundonombre ,
        case when pre_tipopregunta='IN' then f.per_primerapellido end per_primerapellido ,
        case when pre_tipopregunta='IN' then f.per_segundoapellido end per_segundoapellido ,
        case when pre_tipopregunta='IN' then GIC_N_CARACTERIZACION.FN_COMPROBARVALIDACIONES(f.per_idpersona, f.PRE_IDPREGUNTA, pHOG_CODIGO, pINS_IDINSTRUMENTO) end validacion_persona,
        case when  GIC_N_CARACTERIZACION.FN_GET_MAXPRENTASXTEMA(pID_TEMA) = f.PRE_IDPREGUNTA then 'U' ELSE case when f.PRE_IDPREGUNTA = pID_PREGUNTA then 'P' ELSE 'I' end end ORDENPRIORIDAD,
        IXP_ORDEN,
        case when pre_tipopregunta='IN' then  f.PER_FECHANACIMIENTO  end PER_FECHANACIMIENTO ,
        case when pre_tipopregunta='IN' then f.PER_NUMERODOC end PER_NUMERODOC
        from
        (
        SELECT i.PRE_IDPREGUNTA,p.pre_pregunta,pre_tipopregunta,  pre_tipocampo, hog_codigo, per_idpersona, per_primernombre,
        per_segundonombre, per_primerapellido, per_segundoapellido, i.ixp_orden,  PER_FECHANACIMIENTO, PER_NUMERODOC
        FROM GIC_N_INSTRUMENTOXPREG i
        JOIN GIC_N_PREGUNTAS p on p.pre_idpregunta = i.pre_idpregunta
        ,
        (select hog_codigo, d.per_idpersona, per_primernombre, per_segundonombre, per_primerapellido, per_segundoapellido,
        PER_FECHANACIMIENTO, PER_NUMERODOC
        from gic_miembros_hogar d, gic_persona e
        WHERE d.per_idpersona=e.per_idpersona
              AND HOG_CODIGO=pHOG_CODIGO
        )
      WHERE  IXP_ORDEN = pCont_Preg
              AND i.PRE_ACTIVA='SI'
              AND i.INS_IDINSTRUMENTO=pINS_IDINSTRUMENTO
              AND i.TEM_IDTEMA=pID_TEMA
        ) f
        left join gic_n_preguntas g
        on f.PRE_IDPREGUNTA=g.PRE_IDPREGUNTA
        ORDER BY PER_IDPERSONA
      ;
      
      UPDATE GIC_N_PREGUNTASDERIVADAS PD SET PD.CONTADOR=0 WHERE PD.PRE_IDPREGUNTA = ( SELECT IP.PRE_IDPREGUNTA   FROM GIC_N_INSTRUMENTOXPREG IP  WHERE  IP.IXP_ORDEN = pCont_Preg
              AND IP.PRE_ACTIVA='SI'
              AND IP.INS_IDINSTRUMENTO=pINS_IDINSTRUMENTO
              AND IP.TEM_IDTEMA=pID_TEMA)
      AND PD.HOG_CODIGO=pHOG_CODIGO AND PD.INS_IDINSTRUMENTO = pINS_IDINSTRUMENTO AND PD.TEM_IDTEMA = pID_TEMA;
      COMMIT;
      
    Exception  when others then
    SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_BUSCAR_SIGUIENTE_PREGUNTA','');
    SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_BUSCAR_SIGUIENTE_PREGUNTA','');
    
END  SP_BUSCAR_SIGUIENTE_PREGUNTA;

--BUSCA LA PREGUNTA ANTERIORMENTE GUARDADA
PROCEDURE SP_BUSCAR_ANTERIOR_PREGUNTA(
  pHOG_CODIGO IN VARCHAR2,
  pID_TEMA IN NUMBER,
  pINS_IDINSTRUMENTO IN NUMBER,
  pID_PREGUNTA IN NUMBER,
  cur_OUT OUT GIC_CURSOR.cursor_select
  )
  AS
  pCont_Preg number;
  pID_PREGUNTA_act NUMBER;
  -- pper_idPreguntaPadre number;
  BEGIN

    IF pID_PREGUNTA = 0 THEN
        SELECT MAX(IXP_ORDEN)+1 INTO pCont_Preg  FROM gic_n_respuestasencuesta G
        JOIN gic_n_respuestas A
        ON a.RES_IDRESPUESTA=G.RES_IDRESPUESTA
        LEFT JOIN  GIC_N_INSTRUMENTOXPREG C
        ON A.PRE_IDPREGUNTA=C.PRE_IDPREGUNTA
        WHERE TEM_IDTEMA=pID_TEMA
        AND G.HOG_CODIGO=pHOG_CODIGO
        AND G.INS_IDINSTRUMENTO=pINS_IDINSTRUMENTO;
    ELSE
        SELECT PR.IXP_ORDEN INTO pCont_Preg
        FROM  GIC_N_INSTRUMENTOXPREG PR
        WHERE PR.PRE_IDPREGUNTA=pID_PREGUNTA
        AND PR.TEM_IDTEMA=pID_TEMA;
    END IF;

    OPEN cur_OUT FOR
          SELECT I.PRE_IDPREGUNTA, I.PRE_PREGUNTA, I.PRE_TIPOPREGUNTA, I.PRE_TIPOCAMPO, J.HOG_CODIGO, J.PER_IDPERSONA,
          J.PER_PRIMERNOMBRE, J.PER_SEGUNDONOMBRE, J.PER_PRIMERAPELLIDO, J.PER_SEGUNDOAPELLIDO,
          CASE WHEN I.VALIDACION_PERSONA = 1  THEN I.VALIDACION_PERSONA ELSE 0 END AS VALIDACION_PERSONA , 'I' ORDENPRIORIDAD,
          I.IXP_ORDEN_PREG AS IXP_ORDEN, J.PER_FECHANACIMIENTO, J.PER_NUMERODOC
          FROM
          (select hog_codigo, d.per_idpersona, per_primernombre, per_segundonombre, per_primerapellido, per_segundoapellido,
            PER_FECHANACIMIENTO, PER_NUMERODOC
            from gic_miembros_hogar d, gic_persona e
            WHERE d.per_idpersona=e.per_idpersona
            AND HOG_CODIGO=pHOG_CODIGO
          ) J
          LEFT JOIN
          (SELECT DISTINCT A.PRE_IDPREGUNTA, A.PRE_PREGUNTA, C.PRE_TIPOPREGUNTA, C.PRE_TIPOCAMPO, G.HOG_CODIGO, G.PER_IDPERSONA,
          H.PER_PRIMERNOMBRE, H.PER_SEGUNDONOMBRE, H.PER_PRIMERAPELLIDO, H.PER_SEGUNDOAPELLIDO,
          1 VALIDACION_PERSONA, 'I' ORDENPRIORIDAD,
          C.IXP_ORDEN IXP_ORDEN_PREG, H.PER_FECHANACIMIENTO, H.PER_NUMERODOC
          FROM gic_n_preguntas A
          LEFT JOIN  gic_n_respuestas B
          ON A.PRE_IDPREGUNTA=B.PRE_IDPREGUNTA
          LEFT JOIN  GIC_N_INSTRUMENTOXPREG C
          ON A.PRE_IDPREGUNTA=C.PRE_IDPREGUNTA
          LEFT JOIN  GIC_N_VALXINSTRUMENTO F
          ON A.PRE_IDPREGUNTA=F.PRE_IDPREGUNTA
          LEFT JOIN  gic_n_respuestasencuesta G
          ON B.RES_IDRESPUESTA=G.RES_IDRESPUESTA
          LEFT JOIN (select hog_codigo, d.per_idpersona, per_primernombre, per_segundonombre, per_primerapellido,
                            per_segundoapellido,PER_FECHANACIMIENTO, PER_NUMERODOC

                      from gic_miembros_hogar d, gic_persona e
                      WHERE d.per_idpersona=e.per_idpersona
                            AND HOG_CODIGO=pHOG_CODIGO
                    ) H
          ON G.PER_IDPERSONA=H.PER_IDPERSONA
          WHERE C.TEM_IDTEMA=pID_TEMA AND G.HOG_CODIGO=pHOG_CODIGO
          AND C.IXP_ORDEN=(SELECT MAX(IXP_ORDEN) FROM gic_n_respuestasencuesta G
          JOIN gic_n_respuestas A
          ON a.RES_IDRESPUESTA=G.RES_IDRESPUESTA
          LEFT JOIN  GIC_N_INSTRUMENTOXPREG C
          ON A.PRE_IDPREGUNTA=C.PRE_IDPREGUNTA
          WHERE TEM_IDTEMA= pID_TEMA
          AND G.HOG_CODIGO=pHOG_CODIGO
           AND IXP_ORDEN<pCont_Preg)
          AND C.INS_IDINSTRUMENTO=pINS_IDINSTRUMENTO
          ) I
          ON J.PER_IDPERSONA = I.PER_IDPERSONA ORDER BY I.PER_IDPERSONA
         ;
--CARGA LA PREGUNTA QUE SE VA A MOSTRAR
          SELECT max(I.PRE_IDPREGUNTA) INTO pID_PREGUNTA_act
          FROM
          (select hog_codigo, d.per_idpersona, per_primernombre, per_segundonombre, per_primerapellido, per_segundoapellido,
            PER_FECHANACIMIENTO, PER_NUMERODOC
            from gic_miembros_hogar d, gic_persona e
            WHERE d.per_idpersona=e.per_idpersona
            AND HOG_CODIGO=pHOG_CODIGO
          ) J
          LEFT JOIN
          (SELECT DISTINCT A.PRE_IDPREGUNTA, A.PRE_PREGUNTA, C.PRE_TIPOPREGUNTA, C.PRE_TIPOCAMPO, G.HOG_CODIGO, G.PER_IDPERSONA,
          H.PER_PRIMERNOMBRE, H.PER_SEGUNDONOMBRE, H.PER_PRIMERAPELLIDO, H.PER_SEGUNDOAPELLIDO,
          1 VALIDACION_PERSONA, 'I' ORDENPRIORIDAD,
          C.IXP_ORDEN IXP_ORDEN_PREG, H.PER_FECHANACIMIENTO, H.PER_NUMERODOC
          FROM gic_n_preguntas A
          LEFT JOIN  gic_n_respuestas B
          ON A.PRE_IDPREGUNTA=B.PRE_IDPREGUNTA
          LEFT JOIN  GIC_N_INSTRUMENTOXPREG C
          ON A.PRE_IDPREGUNTA=C.PRE_IDPREGUNTA
          LEFT JOIN  GIC_N_VALXINSTRUMENTO F
          ON A.PRE_IDPREGUNTA=F.PRE_IDPREGUNTA
          LEFT JOIN  gic_n_respuestasencuesta G
          ON B.RES_IDRESPUESTA=G.RES_IDRESPUESTA
          LEFT JOIN (select hog_codigo, d.per_idpersona, per_primernombre, per_segundonombre, per_primerapellido,
                            per_segundoapellido,PER_FECHANACIMIENTO, PER_NUMERODOC

                      from gic_miembros_hogar d, gic_persona e
                      WHERE d.per_idpersona=e.per_idpersona
                            AND HOG_CODIGO=pHOG_CODIGO
                    ) H
          ON G.PER_IDPERSONA=H.PER_IDPERSONA
          WHERE C.TEM_IDTEMA=pID_TEMA AND G.HOG_CODIGO=pHOG_CODIGO
          AND C.IXP_ORDEN=(SELECT MAX(IXP_ORDEN) FROM gic_n_respuestasencuesta G
          JOIN gic_n_respuestas A
          ON a.RES_IDRESPUESTA=G.RES_IDRESPUESTA
          LEFT JOIN  GIC_N_INSTRUMENTOXPREG C
          ON A.PRE_IDPREGUNTA=C.PRE_IDPREGUNTA
          WHERE TEM_IDTEMA= pID_TEMA
          AND G.HOG_CODIGO=pHOG_CODIGO
           AND IXP_ORDEN<pCont_Preg)
          AND C.INS_IDINSTRUMENTO=pINS_IDINSTRUMENTO
          ) I
          ON J.PER_IDPERSONA = I.PER_IDPERSONA ORDER BY I.PRE_IDPREGUNTA
         ;
--Borra las respuestas de las preguntas hijas
gic_n_caracterizacion.SP_BORRAR_PREG_DERIV(pID_PREGUNTA_act, pHOG_CODIGO, pID_TEMA, pINS_IDINSTRUMENTO);

--GUARDADO EN 0 PARA LAS PREGUNTAS POSTERIORES
UPDATE gic_n_preguntasderivadas SET GUARDADO=0, CONTADOR = 0
WHERE HOG_CODIGO=pHOG_CODIGO AND gic_n_preguntasderivadas.pre_idpregunta
IN (
select t.pre_idpregunta
from gic_n_preguntasderivadas t
LEFT JOIN GIC_N_INSTRUMENTOXPREG u
ON u.pre_idpregunta=T.PRE_IDPREGUNTA
WHERE hog_codigo=pHOG_CODIGO
AND T.TEM_IDTEMA=pID_TEMA
AND U.IXP_ORDEN>=(SELECT V.IXP_ORDEN FROM GIC_N_INSTRUMENTOXPREG V WHERE V.PRE_IDPREGUNTA=pID_PREGUNTA_act)
);
COMMIT;
      
Exception  when others then
SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_BUSCAR_ANTERIOR_PREGUNTA','');
SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_BUSCAR_ANTERIOR_PREGUNTA','');

END SP_BUSCAR_ANTERIOR_PREGUNTA;

--Borra las respuestas de las preguntas hijas de la tabla de preguntas derivadas
PROCEDURE SP_BORRAR_PREG_DERIV (pID_PREGUNTA_act NUMBER,
  pHOG_CODIGO IN VARCHAR2,
  pID_TEMA IN NUMBER,
  pINS_IDINSTRUMENTO IN NUMBER
)
AS
BEGIN

DELETE FROM Gic_n_Preguntasderivadas
WHERE
hog_codigo=pHOG_CODIGO
AND INS_IDINSTRUMENTO=pINS_IDINSTRUMENTO
AND TEM_IDTEMA=pID_TEMA
AND PRE_IDPREGUNTAPADRE = pID_PREGUNTA_act
AND PRE_IDPREGUNTA IN(
SELECT DISTINCT PRE_IDPREGUNTA
FROM (
WITH
RESPUESTAS_ELIMINAR (PRE_IDPREGUNTA, PRE_IDPREGUNTAPADRE) AS
(
SELECT DISTINCT PRE_IDPREGUNTA, PRE_IDPREGUNTAPADRE
FROM gic_n_preguntasderivadas
WHERE PRE_IDPREGUNTAPADRE = pID_PREGUNTA_act
AND hog_codigo=pHOG_CODIGO
AND TEM_IDTEMA=pID_TEMA
UNION ALL
SELECT E.PRE_IDPREGUNTA, E.PRE_IDPREGUNTAPADRE
FROM RESPUESTAS_ELIMINAR r, gic_n_preguntasderivadas e
WHERE r.PRE_IDPREGUNTA = e.PRE_IDPREGUNTAPADRE
AND E.hog_codigo=pHOG_CODIGO
AND E.TEM_IDTEMA=pID_TEMA
)
SELECT DISTINCT PRE_IDPREGUNTA
FROM RESPUESTAS_ELIMINAR))
;

Exception  when others then
SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_BORRAR_PREG_DERIV','');
SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_BORRAR_PREG_DERIV','');

END SP_BORRAR_PREG_DERIV;

--CAMBIA EL ESTADO EN A GUARDADO=1
PROCEDURE SP_CAMBIAR_ESTADOGUARDADO(
     pHOG_CODIGO IN VARCHAR2,
     pINS_IDINSTRUMENTO IN NUMBER,
     pPER_IDPERSONA IN NUMBER,
     pRES_IDRESPUESTA IN NUMBER
  )
  AS
  BEGIN
    UPDATE GIC_N_PREGUNTASDERIVADAS T SET GUARDADO=1
    WHERE T.HOG_CODIGO= pHOG_CODIGO
        AND T.INS_IDINSTRUMENTO=pINS_IDINSTRUMENTO AND T.PRE_IDPREGUNTA=pRES_IDRESPUESTA ;
    
    COMMIT;
    
    Exception  when others then
    SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_CAMBIAR_ESTADOGUARDADO','');
    SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_CAMBIAR_ESTADOGUARDADO','');
    
    
   END SP_CAMBIAR_ESTADOGUARDADO;

--ELIMINAR PREGUNTAS DERIVADAS :ACCION ANTERIOR
PROCEDURE SP_SET_LIMPIAR_PRE_DERIVADAS
  (
     pRES_IDRESPUESTANTERIOR IN NUMBER,
     pHOG_CODIGO IN VARCHAR2,
     pID_TEMA IN NUMBER,
     pTIPO IN NUMBER,
     pIDPREGUNTA IN NUMBER,
     pIDPREGUNTAACTUAL IN NUMBER
  )
  AS
  BEGIN
    IF pTIPO <>0 THEN
 -- DELETE FROM GIC_N_PREGUNTASDERIVADAS T WHERE T.PRE_IDPREGUNTAPADRE=pRES_IDRESPUESTANTERIOR AND T.HOG_CODIGO=pHOG_CODIGO AND T.TEM_IDTEMA=pID_TEMA;
     IF pRES_IDRESPUESTANTERIOR = pIDPREGUNTAACTUAL THEN
     
     for cur_act in (SELECT t.hog_codigo,t.tem_idtema, t.pre_idpreguntapadre, t.pre_idpregunta from
        GIC_N_PREGUNTASDERIVADAS t
         WHERE T.HOG_CODIGO=pHOG_CODIGO AND T.TEM_IDTEMA=pID_TEMA
         AND T.PRE_IDPREGUNTAPADRE =pRES_IDRESPUESTANTERIOR
         --AND T.PRE_IDPREGUNTA=pIDPREGUNTA
        ) loop
        
         delete from GIC_N_PREGUNTASDERIVADAS t
         WHERE t.hog_codigo=cur_act.hog_codigo and 
         t.tem_idtema=cur_act.tem_idtema and  
         t.pre_idpreguntapadre=cur_act.pre_idpreguntapadre and  
         t.pre_idpregunta=cur_act.pre_idpregunta;
         
        end loop;
    
        UPDATE GIC_N_PREGUNTASDERIVADAS T  SET T.GUARDADO=0  WHERE T.HOG_CODIGO=pHOG_CODIGO AND T.PRE_IDPREGUNTA=pRES_IDRESPUESTANTERIOR;
     ELSE
            UPDATE GIC_N_PREGUNTASDERIVADAS T  SET T.GUARDADO=0  WHERE T.HOG_CODIGO=pHOG_CODIGO AND T.PRE_IDPREGUNTA=pIDPREGUNTAACTUAL;
        END IF;
    COMMIT;
    UPDATE GIC_N_PREGUNTASDERIVADAS T  SET T.GUARDADO=0
    WHERE T.HOG_CODIGO=pHOG_CODIGO AND T.PRE_IDPREGUNTA= (SELECT  t.pre_idpregunta as PREGUNTAACTUAL
    FROM GIC_N_PREGUNTASDERIVADAS t
    join GIC_N_INSTRUMENTOXPREG PR on pr.pre_idpregunta= t.pre_idpreguntapadre
    WHERE t.hog_codigo=pHOG_CODIGO  AND t.tem_idtema=pID_TEMA AND pr.ixp_orden =(SELECT   MAX(pr.ixp_orden) as PREGUNTAACTUAL
    FROM GIC_N_PREGUNTASDERIVADAS t
    join GIC_N_INSTRUMENTOXPREG PR on pr.pre_idpregunta= t.pre_idpreguntapadre
    WHERE t.hog_codigo=pHOG_CODIGO  AND t.tem_idtema=pID_TEMA));
    ELSE
    UPDATE GIC_N_PREGUNTASDERIVADAS T SET T.GUARDADO=0 WHERE T.HOG_CODIGO=pHOG_CODIGO AND T.PRE_IDPREGUNTA=pRES_IDRESPUESTANTERIOR;
    END IF;
    COMMIT;
    
    Exception  when others then
    SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_SET_LIMPIAR_PRE_DERIVADAS','');
    SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_SET_LIMPIAR_PRE_DERIVADAS','');
    
END SP_SET_LIMPIAR_PRE_DERIVADAS;

--TRAE LAS RESPUESTAS A LA PREGUNTA
PROCEDURE SP_GET_RESPUESTASXPREGUNTA
   (
     pPRE_IDPREGUNTA IN NUMBER,
     cur_OUT OUT SYS_REFCURSOR
  )
  AS
  pPRE_DEPENDE NUMBER;
  BEGIN
     OPEN cur_OUT FOR
     --NR-2020-05
      SELECT ri.ins_idinstrumento,ri.res_idrespuesta,re.res_respuesta,
             ri.pre_validador, ri.pre_longcampo, re.pre_idpregunta,
             ri.pre_validador_min, ri.pre_validador_max, ri.res_ordenrespuesta,
             ri.pre_campotex, ri.res_obligatorio, ri.res_habilita,
             ri.res_finaliza, ri.res_autocompletar
        FROM gic_n_instrumentoxresp ri,
             gic_n_respuestas re, 
             gic_n_instrumentoxpreg pre 
        WHERE re.res_idrespuesta=ri.res_idrespuesta 
          AND re.res_activa='SI'
          AND pre.pre_idpregunta = re.pre_idpregunta
          AND re.pre_idpregunta = pPRE_IDPREGUNTA;
      
  EXCEPTION  WHEN OTHERS THEN
    SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_GET_RESPUESTASXPREGUNTA','');
    SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_GET_RESPUESTASXPREGUNTA','');
    
   END  SP_GET_RESPUESTASXPREGUNTA;
--TRAE LAS PERSONAS QUE CUMPLAN LAS VALIDACIONES Y LAS CONDICIONES
PROCEDURE SP_GET_TRAERPERSONAS(
     pPRE_IDPREGUNTA IN NUMBER,
     pHOG_CODIGO IN VARCHAR2,
     pINS_IDINSTRUMENTO IN NUMBER,
     cur_OUT OUT GIC_CURSOR.cursor_select
  )
    AS
    BEGIN
        OPEN cur_OUT FOR
             SELECT DISTINCT PE.PER_IDPERSONA,PE.PER_PRIMERNOMBRE, PE.PER_SEGUNDONOMBRE, PE.PER_PRIMERAPELLIDO, PE.PER_SEGUNDOAPELLIDO
             FROM GIC_PERSONA PE
             JOIN GIC_N_VALIDADORESXPERSONA VP ON VP.PER_IDPERSONA=PE.PER_IDPERSONA
             JOIN GIC_N_PREGUNTASDERIVADAS PD ON PD.PER_IDPERSONA=VP.PER_IDPERSONA
             WHERE (GIC_N_CARACTERIZACION.FN_COMPROBARVALIDACIONES(PE.PER_IDPERSONA,pPRE_IDPREGUNTA, pHOG_CODIGO,pINS_IDINSTRUMENTO)=1
             OR GIC_N_CARACTERIZACION.FN_COMPROBARVALIDACIONES(PE.PER_IDPERSONA,pPRE_IDPREGUNTA, pHOG_CODIGO,pINS_IDINSTRUMENTO)=2 )
             AND PD.PRE_IDPREGUNTA=pPRE_IDPREGUNTA
             AND PD.INS_IDINSTRUMENTO=pINS_IDINSTRUMENTO
             AND PD.HOG_CODIGO=pHOG_CODIGO;
             
    Exception  when others then
    SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_GET_TRAERPERSONAS','');
    SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_GET_TRAERPERSONAS','');
    
END SP_GET_TRAERPERSONAS;

FUNCTION FN_COMPROBARVALIDACIONES(pPER_IDPERSONA IN NUMBER, pPRE_IDPREGUNTA IN NUMBER,pHOG_CODIGO IN VARCHAR, pINS_IDINSTRUMENTO IN NUMBER) RETURN INTEGER
  IS Result integer;
   EXISTE NUMBER;
   CONT NUMBER;
   TOTAL NUMBER;
   IXP_ORDEN NUMBER;
   TIENE_VAL NUMBER;
   valor varchar2(100);
   Val_DIFerenciado varchar2(1000);
   VAL_PREG_GENERAL  varchar2(1000);
   Val_DIFerenciado_Res varchar2(1000);
   Val_Encontrados varchar2(100);
   Inic_cadena NUMBER;
   Fin_cadena NUMBER;
   Pos_cadena NUMBER;
   Val_cadena varchar2(20);
   CONDICION varchar2(1000);
   RESULTADO varchar2(1000);
   BUSRESPUESTAS NUMBER;
BEGIN
     CONT :=0;
     Result:= 0;
--BUSCAR EL ORDEN DE LA PREGUNTA
SELECT IXP_ORDEN, Val_DIFerenciado, VAL_PREG_GENERAL  INTO IXP_ORDEN, Val_DIFerenciado, VAL_PREG_GENERAL from gic_n_instrumentoxpreg WHERE PRE_IDPREGUNTA=pPRE_IDPREGUNTA AND INS_IDINSTRUMENTO=pINS_IDINSTRUMENTO;
IF Val_DIFerenciado IS NULL AND VAL_PREG_GENERAL IS NULL THEN
    IF IXP_ORDEN >0 THEN
          --Busca los validadores para la pregunta
          SELECT COUNT(1) INTO TIENE_VAL FROM GIC_N_VALXINSTRUMENTO
          WHERE PRE_IDPREGUNTA IN (pPRE_IDPREGUNTA);

          --Busca a la persona en preguntas derivadas
          SELECT COUNT(1) INTO TOTAL FROM GIC_N_PREGUNTASDERIVADAS T
          WHERE HOG_CODIGO=PHOG_CODIGO AND PER_IDPERSONA=PPER_IDPERSONA
          AND PRE_IDPREGUNTA=PPRE_IDPREGUNTA
          ORDER BY PRE_IDPREGUNTA DESC;

          IF TOTAL > 0 THEN
            TOTAL :=1;
          END IF;

       IF (IXP_ORDEN =1 AND TIENE_VAL>=1) OR (IXP_ORDEN <>1 AND TIENE_VAL>=1 AND TOTAL=1) THEN
                    FOR CUR_DATOS IN (SELECT DISTINCT * FROM (
                                        SELECT  * FROM GIC_N_VALXINSTRUMENTO
                                        WHERE PRE_IDPREGUNTA IN (pPRE_IDPREGUNTA)
                                        UNION SELECT * FROM GIC_N_VALXINSTRUMENTO
                                        WHERE PRE_IDPREGUNTA IN (SELECT DISTINCT PRE_IDPREGUNTA FROM GIC_PERSONA PE
                                        JOIN GIC_N_VALIDADORESXPERSONA VP ON VP.PER_IDPERSONA=PE.PER_IDPERSONA
                                        JOIN GIC_N_PREGUNTASDERIVADAS PD ON PD.PER_IDPERSONA=VP.PER_IDPERSONA
                                        WHERE PE.PER_IDPERSONA=pPER_IDPERSONA
                                        AND PD.PRE_IDPREGUNTA = pPRE_IDPREGUNTA)
                                        )
                                      )
          LOOP
              --VERIFICA SI LA PERSONA TIENE VALOR PARA ESTE VALIDADOR
              SELECT COUNT(PRE_VALOR) INTO valor from GIC_N_VALIDADORESXPERSONA VP
              WHERE VP.PER_IDPERSONA=pPER_IDPERSONA AND VP.HOG_CODIGO=pHOG_CODIGO AND VAL_IDVALIDADOR=CUR_DATOS.VAL_IDVALIDADOR_PERS;

              IF VALOR>0 THEN
                --BUSCA EL VALOR DEL VALIDADOR DE LA PERSONA
                SELECT PRE_VALOR INTO valor from GIC_N_VALIDADORESXPERSONA VP
                WHERE VP.PER_IDPERSONA=pPER_IDPERSONA AND VP.HOG_CODIGO=pHOG_CODIGO AND VAL_IDVALIDADOR=CUR_DATOS.VAL_IDVALIDADOR_PERS;
                --verIFica si la persona cumple con la validacion 1 si cumple, 0 no cumple
                EXISTE := GIC_N_CARACTERIZACION.FN_VALIDARPERSONA(valor,CUR_DATOS.VAL_IDVALIDADOR);
              ELSE
                  EXISTE:= 0;
              END IF;

               IF EXISTE =1 THEN
                CONT :=CONT + 1;
               END IF;
                IF TIENE_VAL = CONT THEN
                  Result:= 1;
                ELSE
                  Result:= 0;
                END IF;
             END LOOP;
       ELSIF (IXP_ORDEN =1 AND TIENE_VAL=0) OR (IXP_ORDEN <>1 AND TIENE_VAL=0 AND TOTAL=1) THEN
            Result:= 1;
       ELSIF (IXP_ORDEN <>1 AND TIENE_VAL>=1 AND TOTAL=0) OR (IXP_ORDEN <>1 AND TIENE_VAL=0 AND TOTAL=0) THEN
            Result:= 0;
       END IF;

    ELSE
        Result:=0;
    END IF;
ELSIF VAL_PREG_GENERAL IS NULL THEN  --VALIDA PARA PREGUNTA IN
  Result:=0;
    --validadores dIFerenciados
    TIENE_VAL :=1;

    IF IXP_ORDEN >0 THEN
          --Busca a la persona en preguntas derivadas
          SELECT COUNT(1) INTO TOTAL FROM GIC_N_PREGUNTASDERIVADAS T
          WHERE HOG_CODIGO=PHOG_CODIGO AND PER_IDPERSONA=PPER_IDPERSONA
          AND PRE_IDPREGUNTA=PPRE_IDPREGUNTA
          ORDER BY PRE_IDPREGUNTA DESC;

          IF TOTAL > 0 THEN
            TOTAL :=1;
          END IF;

       IF (IXP_ORDEN =1 AND TIENE_VAL>=1) OR (IXP_ORDEN <>1 AND TIENE_VAL>=1 AND TOTAL=1) THEN
          --Val_DIFerenciado
            Pos_cadena:= 1;
          LOOP
            Inic_cadena:= instr(Val_DIFerenciado,'(',Pos_cadena);
            Fin_cadena:= instr(Val_DIFerenciado,')',Pos_cadena);
            Pos_cadena:= Fin_cadena+1;

            val_cadena:= substr(Val_DIFerenciado,Inic_cadena+1,Fin_cadena-Inic_cadena-1);
            Inic_cadena:= instr(val_cadena,',',1);

            --validador de la persona
            Fin_cadena:= substr(val_cadena,Inic_cadena+1);
            --validador del instrumento
            Inic_cadena:= substr(val_cadena,1,Inic_cadena-1);

              --VERIFICA SI LA PERSONA TIENE VALOR PARA ESTE VALIDADOR
              SELECT COUNT(PRE_VALOR) INTO valor from GIC_N_VALIDADORESXPERSONA VP
              WHERE VP.PER_IDPERSONA=pPER_IDPERSONA AND VP.HOG_CODIGO=pHOG_CODIGO AND VAL_IDVALIDADOR=Fin_cadena;

              IF VALOR>0 THEN
                --BUSCA EL VALOR DEL VALIDADOR DE LA PERSONA
                SELECT PRE_VALOR INTO valor from GIC_N_VALIDADORESXPERSONA VP
                WHERE VP.PER_IDPERSONA=pPER_IDPERSONA AND VP.HOG_CODIGO=pHOG_CODIGO AND VAL_IDVALIDADOR=Fin_cadena;
                --verIFica si la persona cumple con la validacion 1 si cumple, 0 no cumple
                EXISTE := GIC_N_CARACTERIZACION.FN_VALIDARPERSONA(valor,Inic_cadena);
              ELSE
                  EXISTE:= 0;
              END IF;

               IF EXISTE =1 THEN
                    Val_DIFerenciado_Res := Val_DIFerenciado_Res || '(' || val_cadena || ')';
               ELSE
                    Val_DIFerenciado_Res := Val_DIFerenciado_Res || '(x,x)';
               END IF;
                    val_cadena:= substr(Val_DIFerenciado,Pos_cadena,3);
               IF UPPER(val_cadena) =' OR' OR Pos_cadena> length(Val_DIFerenciado) THEN
                       
                          CONDICION := 'INSTR(''' || Val_DIFerenciado || ''',''' || Val_DIFerenciado_Res || ''',1)>0';
                          RESULTADO := 'SELECT CASE WHEN ' || CONDICION || ' THEN 1 ELSE 0 END FROM DUAL';
                          EXECUTE IMMEDIATE RESULTADO INTO BUSRESPUESTAS;
                         IF BUSRESPUESTAS=0 THEN
                           Val_DIFerenciado_Res :='';
                           Result :=0;
                         ELSE
                           Result :=1;
                           EXIT;
                         END IF;
               END IF;
             IF Pos_cadena> length(Val_DIFerenciado) then
                EXIT;
             END IF;
          END LOOP;
       ELSIF (IXP_ORDEN =1 AND TIENE_VAL=0) OR (IXP_ORDEN <>1 AND TIENE_VAL=0 AND TOTAL=1) THEN
            Result:= 1;
       ELSIF (IXP_ORDEN <>1 AND TIENE_VAL>=1 AND TOTAL=0) OR (IXP_ORDEN <>1 AND TIENE_VAL=0 AND TOTAL=0) THEN
            Result:= 0;
       END IF;

    ELSE
        Result:=0;
    END IF;
ELSE --VALIDA PARA PREGUNTA IN
  Result:=0;
    --validadores dIFerenciados
    TIENE_VAL :=1;

    IF IXP_ORDEN >0 THEN
          --Busca a la persona en preguntas derivadas
          FOR CUR_DATOS IN (select T.PER_IDPERSONA from GIC_MIEMBROS_HOGAR t WHERE hog_codigo=pHOG_CODIGO
                           )
          LOOP
               TOTAL :=1;
               IF (IXP_ORDEN =1 AND TIENE_VAL>=1) OR (IXP_ORDEN <>1 AND TIENE_VAL>=1 AND TOTAL=1) THEN
                  --Val_DIFerenciado
                    Pos_cadena:= 1;
                  LOOP
                    Inic_cadena:= instr(VAL_PREG_GENERAL,'(',Pos_cadena);
                    Fin_cadena:= instr(VAL_PREG_GENERAL,')',Pos_cadena);
                    Pos_cadena:= Fin_cadena+1;

                    val_cadena:= substr(VAL_PREG_GENERAL,Inic_cadena+1,Fin_cadena-Inic_cadena-1);
                    Inic_cadena:= instr(val_cadena,',',1);

                    --validador de la persona
                    Fin_cadena:= substr(val_cadena,Inic_cadena+1);
                    --validador del instrumento
                    Inic_cadena:= substr(val_cadena,1,Inic_cadena-1);

                      --VERIFICA SI LA PERSONA TIENE VALOR PARA ESTE VALIDADOR
                      SELECT COUNT(PRE_VALOR) INTO valor from GIC_N_VALIDADORESXPERSONA VP
                      WHERE VP.PER_IDPERSONA=CUR_DATOS.PER_IDPERSONA AND VP.HOG_CODIGO=pHOG_CODIGO AND VAL_IDVALIDADOR=Fin_cadena;

                      IF VALOR>0 THEN
                        --BUSCA EL VALOR DEL VALIDADOR DE LA PERSONA
                        SELECT PRE_VALOR INTO valor from GIC_N_VALIDADORESXPERSONA VP
                        WHERE VP.PER_IDPERSONA=CUR_DATOS.PER_IDPERSONA AND VP.HOG_CODIGO=pHOG_CODIGO AND VAL_IDVALIDADOR=Fin_cadena;
                        --verIFica si la persona cumple con la validacion 1 si cumple, 0 no cumple
                        EXISTE := GIC_N_CARACTERIZACION.FN_VALIDARPERSONA(valor,Inic_cadena);
                      ELSE
                          EXISTE:= 0;
                      END IF;

                       IF EXISTE =1 THEN
                            Val_DIFerenciado_Res := Val_DIFerenciado_Res || '(' || val_cadena || ')';
                       ELSE
                            Val_DIFerenciado_Res := Val_DIFerenciado_Res || '(x,x)';
                       END IF;
                            val_cadena:= substr(VAL_PREG_GENERAL,Pos_cadena,3);
                       IF UPPER(val_cadena) =' OR' OR Pos_cadena> length(VAL_PREG_GENERAL) THEN
                                 
                                  CONDICION := 'INSTR(''' || VAL_PREG_GENERAL || ''',''' || Val_DIFerenciado_Res || ''',1)>0';
                                  RESULTADO := 'SELECT CASE WHEN ' || CONDICION || ' THEN 1 ELSE 0 END FROM DUAL';
                                  EXECUTE IMMEDIATE RESULTADO INTO BUSRESPUESTAS;
                                 IF BUSRESPUESTAS=0 THEN
                                   Val_DIFerenciado_Res :='';
                                   Result :=0;
                                 ELSE
                                   Result :=1;
                                   EXIT;
                                 END IF;
                       END IF;
                     IF Pos_cadena> length(VAL_PREG_GENERAL) then
                        EXIT;
                     END IF;
                  END LOOP;
                  IF Result =1 THEN --ALGUNA PERSONA CUMPLE LA CONDICION
                     EXIT;
                  END IF;
               ELSIF (IXP_ORDEN =1 AND TIENE_VAL=0) OR (IXP_ORDEN <>1 AND TIENE_VAL=0 AND TOTAL=1) THEN
                    Result:= 1;
               ELSIF (IXP_ORDEN <>1 AND TIENE_VAL>=1 AND TOTAL=0) OR (IXP_ORDEN <>1 AND TIENE_VAL=0 AND TOTAL=0) THEN
                    Result:= 0;
               END IF;
       END LOOP;
    ELSE
        Result:=0;
    END IF;
END IF;
RETURN Result;
 -- excepcion en caso de otro error;
      Exception  when others then

      SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'FN_COMPROBARVALIDACIONES','');
      SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'FN_COMPROBARVALIDACIONES','');
      return 2;

            
            
END FN_COMPROBARVALIDACIONES;

--Trae el Hogar
--Buscar por codigo hogar
PROCEDURE SP_GET_HOGARXCODIGO
  (
  pHOG_CODIGO IN VARCHAR2,
  cur_OUT OUT GIC_CURSOR.cursor_select
  )
  AS
  BEGIN
  OPEN  cur_OUT FOR
  SELECT HOG_ID, HOG_CODIGO, USU_USUARIOCREACION, USU_IDUSUARIO, USU_FECHACREACION, TPOCRN_ID,  HOG_CODIGOENCUESTA
  FROM GIC_HOGAR
  WHERE HOG_CODIGO=pHOG_CODIGO;
  
  Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_GET_HOGARXCODIGO','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_GET_HOGARXCODIGO','');
  
END SP_GET_HOGARXCODIGO;

--Genera codigo aleatoria de 5 caracteres
FUNCTION FN_GET_GENERAR_CODIGO_ENCUESTA RETURN VARCHAR2

IS codigo VARCHAR2(6);
Decision VARCHAR(2);
valor VARCHAR2(2);

i INTEGER;
BEGIN
  codigo:=null;
  i:=0;
WHILE i < 5
LOOP
  select ROUND(dbms_rANDom.value(0,9),0) INTO Decision From dual;
  IF Decision <5 THEN
      select ROUND(dbms_rANDom.value(0,9),0) INTO valor  from dual;
  ELSE
      select dbms_rANDom.string('U', 1) INTO valor from dual;
  END IF;
  codigo := CONCAT(codigo,valor);
  i:=i+1;
END LOOP;

RETURN CODIGO;


Exception  when others then
SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'FN_GET_GENERAR_CODIGO_ENCUESTA','');
SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'FN_GET_GENERAR_CODIGO_ENCUESTA','');

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
    SELECT count(HOG_CODIGOENCUESTA) INTO Existe
    FROM GIC_HOGAR
    WHERE HOG_CODIGOENCUESTA=Codigo;
  
    
    IF Existe = 0 THEN
      i:=0;
    END IF;
  END LOOP;
  Result := Codigo;
  RETURN Result;
  
  Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'FN_GET_CODIGOENCUESTA','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'FN_GET_CODIGOENCUESTA','');
  
END FN_GET_CODIGOENCUESTA;

--DEVUELVE EL MAXIMO PRE_IDPREGUNTA DE UN TEMA
FUNCTION FN_GET_MAXPRENTASXTEMA(pIDTEMA IN INTEGER) RETURN INTEGER
 IS RESULT INTEGER;
 BEGIN
  SELECT MAX(PRE_IDPREGUNTA) INTO RESULT FROM GIC_N_INSTRUMENTOXPREG T WHERE T.TEM_IDTEMA=pIDTEMA;
  RETURN RESULT;
  END  FN_GET_MAXPRENTASXTEMA;

--ACTUALIZA LOS NOMBRES POR DEFECTO
PROCEDURE SP_ACTUALIZARNOMBRES
(pNombre1 IN VARCHAR2,pNombre2 IN VARCHAR2,pApellido1 IN VARCHAR2,pApellido2 IN VARCHAR2,pIdPersona IN VARCHAR2)
    AS
  BEGIN
    UPDATE GIC_PERSONA T SET T.PER_PRIMERNOMBRE=pNombre1, T.PER_SEGUNDONOMBRE=pNombre2,
    T.PER_PRIMERAPELLIDO=pApellido1, T.PER_SEGUNDOAPELLIDO=pApellido2 WHERE T.PER_IDPERSONA=pIdPersona;
    COMMIT;
    END   SP_ACTUALIZARNOMBRES;

PROCEDURE SP_FINALIZARCAPITULO
(pcodHogar IN VARCHAR2,pidTema IN NUMBER,pusuario IN VARCHAR2)
    AS
  BEGIN
    DELETE FROM gic_n_CAPITULOS_TER T WHERE T.HOG_CODIGO=pcodHogar AND T.TEM_IDTEMA=pidTema;
    COMMIT;
    INSERT INTO gic_n_CAPITULOS_TER(HOG_CODIGO, TEM_IDTEMA, USU_USUARIOCREACION) VALUES (pcodHogar,pidTema,pusuario) ;
    COMMIT;
    
  Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_FINALIZARCAPITULO','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_FINALIZARCAPITULO','');
  
  END SP_FINALIZARCAPITULO;
  
--ELIMINA EL REGISTRO DE CAPITULO TERMINADO Y 
--ACTUALIZA EL ESTADO DE LA ENCUESTA EN LA TABLA GIC_HOGAR
PROCEDURE SP_ELIMINARFINALIZARCAPITULO   
(pcodHogar IN VARCHAR2,pidTema IN NUMBER, pUsuario IN VARCHAR2)
    AS
  BEGIN
    DELETE FROM gic_n_CAPITULOS_TER T WHERE T.HOG_CODIGO=pcodHogar AND T.TEM_IDTEMA=pidTema;
    COMMIT;

    UPDATE GIC_HOGAR
    SET ESTADO = 'ACTIVA', FECHA_ESTADO = SYSDATE, USU_USUARIOESTADO = pUsuario
    WHERE HOG_CODIGO = pcodHogar;
    COMMIT;
    
  Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_ELIMINARFINALIZARCAPITULO','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_ELIMINARFINALIZARCAPITULO','');
  
  END SP_ELIMINARFINALIZARCAPITULO;
    
--ACTUALIZA EL ESTADO DE LA ENCUESTA EN LA TABLA GIC_HOGAR
PROCEDURE SP_ACTUALIZAR_ESTADO_ENCUESTA
(HOGCODIGO IN VARCHAR2, USUARIO IN VARCHAR2, TIPO_APLAZAMIENTO IN VARCHAR2)
AS
   strEstado VARCHAR2(50); conteo INTEGER; totalCT int;   
BEGIN
   
  CASE 
    WHEN TIPO_APLAZAMIENTO = '1' THEN strEstado := 'ANULADA';
    WHEN TIPO_APLAZAMIENTO = '3' THEN strEstado := 'APLAZADA';
    WHEN TIPO_APLAZAMIENTO = '2' then strEstado := 'HOGAR_NO_RESPONDE';
    WHEN TIPO_APLAZAMIENTO = '4' then strEstado := 'CERRADA';    
    WHEN TIPO_APLAZAMIENTO = '5' then strEstado := 'ACTIVA';
    WHEN TIPO_APLAZAMIENTO = '6' then strEstado := 'ERROR'; 
  END CASE;
     
  
  IF strEstado = 'CERRADA' THEN
     SELECT COUNT(T.HOG_CODIGO) INTO totalCT FROM GIC_N_CAPITULOS_TER T WHERE T.HOG_CODIGO = HOGCODIGO;
     IF totalCT > 3 THEN
        UPDATE GIC_HOGAR
        SET ESTADO = strEstado, FECHA_ESTADO = SYSDATE,  USU_USUARIOESTADO = USUARIO
        WHERE HOG_CODIGO = HOGCODIGO;
        -- AND USU_USUARIOESTADO = USUARIO;
         IF TIPO_APLAZAMIENTO NOT IN ('5','3') THEN
              DELETE GIC_N_PREGUNTASDERIVADAS P WHERE P.HOG_CODIGO = HOGCODIGO;
              INSERT INTO GIC_N_RESPUESTASENCUESTA_C SELECT * FROM GIC_N_RESPUESTASENCUESTA R WHERE R.HOG_CODIGO = HOGCODIGO;
              DELETE GIC_N_RESPUESTASENCUESTA R WHERE R.HOG_CODIGO = HOGCODIGO;
         END IF;

         COMMIT;
      ELSE
        NULL;
       END IF;
    ELSE
       
    UPDATE GIC_HOGAR
        SET ESTADO = strEstado, FECHA_ESTADO = SYSDATE,  USU_USUARIOESTADO = USUARIO
        WHERE HOG_CODIGO = HOGCODIGO;
        -- AND USU_USUARIOESTADO = USUARIO;
         IF TIPO_APLAZAMIENTO NOT IN ('5','3') THEN
              DELETE GIC_N_PREGUNTASDERIVADAS P WHERE P.HOG_CODIGO = HOGCODIGO;
              INSERT INTO GIC_N_RESPUESTASENCUESTA_C SELECT * FROM GIC_N_RESPUESTASENCUESTA R WHERE R.HOG_CODIGO = HOGCODIGO;
              DELETE GIC_N_RESPUESTASENCUESTA R WHERE R.HOG_CODIGO = HOGCODIGO;
         END IF;

         COMMIT;
    
    
  END IF;
  
 Exception  when others then
 SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_ACTUALIZAR_ESTADO_ENCUESTA','');
 SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_ACTUALIZAR_ESTADO_ENCUESTA','');
  
END SP_ACTUALIZAR_ESTADO_ENCUESTA;

--CONSULTA EL ESTADO DE LA ENCUESTA EN LA TABLA GIC_N_ESTADO_ENCUESTA
--Agregado Andres Quintero el 14/05/2019
PROCEDURE SP_CONSULTAR_ESTADO_ENCUESTA
(HOGCODIGO IN VARCHAR2, IDUSUARIO IN VARCHAR2, IDPERFILUSUARIO IN VARCHAR2,cur_OUT OUT GIC_CURSOR.cursor_select)
AS
   
BEGIN
       
IF IDPERFILUSUARIO = '1190' THEN
OPEN cur_OUT FOR
SELECT COUNT(T.HOG_CODIGO) TOTAL  FROM GIC_N_CAPITULOS_TER T WHERE T.HOG_CODIGO = HOGCODIGO
AND T.TEM_IDTEMA IN (1,2,3,11);
ELSIF IDPERFILUSUARIO = '1230' THEN
OPEN cur_OUT FOR
SELECT COUNT(T.HOG_CODIGO) TOTAL  FROM GIC_N_CAPITULOS_TER T WHERE T.HOG_CODIGO = HOGCODIGO
AND T.TEM_IDTEMA IN (1,2,3,11);
ELSE 
OPEN cur_OUT FOR
SELECT COUNT(T.HOG_CODIGO) TOTAL  FROM GIC_N_CAPITULOS_TER T WHERE T.HOG_CODIGO = HOGCODIGO;
END IF;   

Exception  when others then
SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_CONSULTAR_ESTADO_ENCUESTA','');
SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_CONSULTAR_ESTADO_ENCUESTA','');

END SP_CONSULTAR_ESTADO_ENCUESTA;

  
--ELIMINA LA ENCUESTA DE LA BASE DE DATOS
PROCEDURE SP_ELIMINAR_ENCUESTA
(HOGCODIGO IN VARCHAR2, USUARIO IN VARCHAR2)
AS

BEGIN

    UPDATE GIC_HOGAR 
    SET ESTADO = 'ANULADA', FECHA_ESTADO = sysdate
    WHERE HOG_CODIGO = HOGCODIGO;
    -- AND USU_USUARIOCREACION = USUARIO;
       
   /*DELETE FROM GIC_N_ESTADO_ENCUESTA WHERE HOG_CODIGO=HOGCODIGO;
   DELETE FROM GIC_N_ENCUESTA_TER WHERE HOG_CODIGO=HOGCODIGO;
   DELETE FROM GIC_N_CAPITULOS_TER WHERE HOG_CODIGO=HOGCODIGO;
   DELETE FROM GIC_N_VALIDADORESXPERSONA WHERE HOG_CODIGO=HOGCODIGO;
   DELETE FROM GIC_N_PREGUNTASDERIVADAS WHERE HOG_CODIGO=HOGCODIGO;
   DELETE FROM GIC_MIEMBROS_HOGAR WHERE HOG_CODIGO=HOGCODIGO;
   DELETE FROM GIC_HOGARXINSTRUMENTO WHERE HOG_CODIGO=HOGCODIGO;   
   DELETE FROM GIC_N_RESPUESTASENCUESTA WHERE HOG_CODIGO=HOGCODIGO;      
   DELETE FROM GIC_HOGAR WHERE HOG_CODIGO=HOGCODIGO;         
   */
   
  DELETE GIC_N_PREGUNTASDERIVADAS P WHERE P.HOG_CODIGO = HOGCODIGO;
  INSERT INTO GIC_N_RESPUESTASENCUESTA_C SELECT * FROM GIC_N_RESPUESTASENCUESTA R WHERE R.HOG_CODIGO = HOGCODIGO;
  DELETE GIC_N_RESPUESTASENCUESTA R WHERE R.HOG_CODIGO = HOGCODIGO;
   
   COMMIT;
   
   
   Exception  when others then
    SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_ELIMINAR_ENCUESTA','');
    SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_ELIMINAR_ENCUESTA','');

END SP_ELIMINAR_ENCUESTA;

--VERIFICA SI YA SE DILIGENCIARON TODOS LOS CAPITULOS Y ACTUALIZA EL ESTADO DE LA ENCUESTA A CERRADA
PROCEDURE SP_VERIFICARFINALIZARENCUESTA (HOGCODIGO IN VARCHAR2, USUARIO IN VARCHAR2)
    AS
    totCapitulos INTEGER;
  BEGIN
    SELECT COUNT(1) INTO totCapitulos FROM GIC_N_CAPITULOS_TER WHERE HOG_CODIGO = HOGCODIGO;    
    
    IF (totCapitulos >= 20) THEN
        UPDATE GIC_HOGAR 
        SET ESTADO = 'CERRADA', FECHA_ESTADO = SYSDATE, USU_USUARIOESTADO = USUARIO
        WHERE HOG_CODIGO = HOGCODIGO;

        COMMIT;
    END IF;
    
  Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_VERIFICARFINALIZARENCUESTA','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_VERIFICARFINALIZARENCUESTA','');
  
  END SP_VERIFICARFINALIZARENCUESTA;
  
--RETORNA EL CODIGO DEL HOGAR SI EL USUARIO TIENE UNA ENCUESTA EN ESTADO 'ACTIVA'
FUNCTION FN_ENCUESTAACTIVA (USUARIO IN VARCHAR2) RETURN VARCHAR2
    IS
    HOGCODIGO VARCHAR2(100);
  BEGIN
    SELECT HOG_CODIGO INTO HOGCODIGO FROM (
        SELECT HOG_CODIGO
        FROM GIC_HOGAR
        WHERE USU_USUARIOESTADO = USUARIO 
              AND ESTADO = 'ACTIVA'
        ORDER BY USU_USUARIOESTADO)
    WHERE ROWNUM = 1;
    RETURN HOGCODIGO;
    
    Exception
     when no_data_found then
     RETURN  '';
     when others then
      SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'FN_ENCUESTAACTIVA','');
      SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'FN_ENCUESTAACTIVA','');
  
     
  END FN_ENCUESTAACTIVA;
  
--RETORNA LA CANTIDAD DE CAPITULOS TERMINADOS QUE TIENE UNA ENCUESTA
FUNCTION FN_NUMERO_CAPITULOS_TER (HOGCODIGO IN VARCHAR2) RETURN INTEGER
    IS
    TOTCAPITULOS INTEGER;
  BEGIN
    SELECT COUNT(1) INTO TOTCAPITULOS FROM GIC_N_CAPITULOS_TER WHERE HOG_CODIGO = HOGCODIGO;    
    RETURN TOTCAPITULOS;
    
  Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'FN_NUMERO_CAPITULOS_TER','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'FN_NUMERO_CAPITULOS_TER','');
     
  END FN_NUMERO_CAPITULOS_TER;
  
--DEVUELVE UN LISTADO DE RESPUESTAS DE UNA ENCUESTA DISCRIMINADAS POR PERSONA Y POR TEMA
PROCEDURE SP_RESPUESTAS_ENCUESTA (HOGCODIGO IN VARCHAR2, cur_OUT OUT gic_cursor.cursor_select)
    AS
  BEGIN
  OPEN cur_OUT FOR    
   SELECT  IP.INS_IDINSTRUMENTO, T.TEM_ORDEN, T.TEM_NOMBRETEMA, PR.PRE_IDPREGUNTA, PR.PRE_PREGUNTA, 
           PE.PER_PRIMERNOMBRE || ' ' || PE.PER_SEGUNDONOMBRE  || ' ' || PE.PER_PRIMERAPELLIDO  || ' ' ||  PE.PER_SEGUNDOAPELLIDO NOMBRE,
           R.RES_RESPUESTA, RE.RXP_TEXTORESPUESTA
    FROM GIC_N_INSTRUMENTOXPREG IP, GIC_TEMA T, GIC_N_PREGUNTAS PR,
     GIC_PERSONA PE, 
         GIC_N_RESPUESTAS R, 
         GIC_N_RESPUESTASENCUESTA_C RE
    WHERE IP.INS_IDINSTRUMENTO = 1 AND
    T.TEM_IDTEMA = IP.TEM_IDTEMA AND
    IP.PRE_IDPREGUNTA = PR.PRE_IDPREGUNTA AND
    RE.PER_IDPERSONA = PE.PER_IDPERSONA AND
    RE.HOG_CODIGO = HOGCODIGO AND
    R.PRE_IDPREGUNTA = PR.PRE_IDPREGUNTA AND
    RE.RES_IDRESPUESTA = R.RES_IDRESPUESTA AND
    RE.PER_IDPERSONA = PE.PER_IDPERSONA AND
    (R.RES_RESPUESTA IS NOT NULL OR
    RE.RXP_TEXTORESPUESTA IS NOT NULL)
    ORDER BY T.TEM_ORDEN, IP.IXP_ORDEN;
    
  Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_RESPUESTAS_ENCUESTA','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_RESPUESTAS_ENCUESTA','');
  
END SP_RESPUESTAS_ENCUESTA;
   
  
--TRAE LAS RESPUESTAS GUARDADAS
PROCEDURE SP_GET_RESPUESTAXPREGUNTA

(
 COD_HOGAR IN VARCHAR2,
 IDTEMA IN NUMBER,
 cur_OUT OUT SYS_REFCURSOR
)
AS
BEGIN
  OPEN cur_OUT FOR  
  --NR-2020-05
  SELECT DISTINCT rh.rxp_idrespuestaxpersona,rh.hog_codigo,
          rh.per_idpersona,rh.res_idrespuesta,rh.rxp_textorespuesta
          ,rh.rxp_tipopregunta,rh.ins_idinstrumento,re.pre_idpregunta                
    FROM gic_n_respuestasencuesta rh,
         gic_miembros_hogar mh, 
         gic_n_respuestas re, 
         gic_n_instrumentoxpreg gp, 
         gic_tema te,
         gic_n_validadoresxpersona p 
   WHERE mh.hog_codigo = rh.hog_codigo 
     AND rh.per_idpersona = mh.per_idpersona
     AND re.res_idrespuesta = rh.res_idrespuesta
     AND gp.pre_idpregunta= re.pre_idpregunta
     AND te.tem_idtema = gp.tem_idtema 
     AND te.tem_idtema= IDTEMA
     AND rh.hog_codigo=p.hog_codigo
     AND mh.hog_codigo= COD_HOGAR 
   ORDER BY rh.per_idpersona;

EXCEPTION  WHEN OTHERS THEN
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_GET_RESPUESTAXPREGUNTA','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_GET_RESPUESTAXPREGUNTA','');
  
END SP_GET_RESPUESTAXPREGUNTA;

--COMPRUEBA SI EL CAPITULO YA ESTA FINALIZADO
PROCEDURE SP_GET_TEMAFINALIZADO

(
 pIDTEMA IN NUMBER,
  pCOD_HOGAR IN VARCHAR2,
 cur_OUT OUT gic_cursor.cursor_select
)
AS
BEGIN
  OPEN cur_OUT FOR
 SELECT COUNT(TEM_IDTEMA) AS TOTAL FROM gic_n_CAPITULOS_TER TD
    WHERE TD.HOG_CODIGO=pCOD_HOGAR AND TD.TEM_IDTEMA=pIDTEMA;
    
   Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_GET_TEMAFINALIZADO','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_GET_TEMAFINALIZADO','');
  
END SP_GET_TEMAFINALIZADO;


--RETORNA ESTADO QUE TIENE UNA ENCUESTA
FUNCTION FN_ESTADO_ENCUESTA (HOGCODIGO IN VARCHAR2) RETURN VARCHAR2
    IS
    ESTADO VARCHAR2(100);
  BEGIN
    SELECT H.ESTADO INTO ESTADO FROM GIC_HOGAR H WHERE HOG_CODIGO = HOGCODIGO;    
    RETURN ESTADO;
    
  Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'FN_ESTADO_ENCUESTA','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'FN_ESTADO_ENCUESTA','');
     
END FN_ESTADO_ENCUESTA;

--RETORNA ID DE UNA ENCUESTA
FUNCTION FN_ID_ENCUESTA (HOGCODIGO IN VARCHAR2) RETURN VARCHAR2
    IS
    ID VARCHAR2(100);
  BEGIN
    SELECT H.HOG_ID INTO ID FROM GIC_HOGAR H WHERE HOG_CODIGO = HOGCODIGO;    
    RETURN ID;
    
  Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'FN_ID_ENCUESTA','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'FN_ID_ENCUESTA','');
    
  END FN_ID_ENCUESTA;
    
--RETORNA USUARIO DE CREACION DE UNA ENCUESTA
FUNCTION FN_USUARIOCREACION_ENCUESTA (HOGCODIGO IN VARCHAR2) RETURN VARCHAR2
    IS
    USUARIO VARCHAR2(100);
  BEGIN
    --SELECT H.USU_USUARIOCREACION INTO USUARIO FROM GIC_HOGAR H WHERE HOG_CODIGO = HOGCODIGO; 
    SELECT H.USU_USUARIOESTADO INTO USUARIO FROM GIC_HOGAR H WHERE HOG_CODIGO = HOGCODIGO;           
    RETURN USUARIO;
    
    
  Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'FN_USUARIOCREACION_ENCUESTA','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'FN_USUARIOCREACION_ENCUESTA','');
     
END FN_USUARIOCREACION_ENCUESTA;

--TRAE MAXIMO ID PREGUNTA PADRE PARA COMPROBAR CUAL ES LA PREGUNTA  SIGUIENTE.
PROCEDURE SP_GET_MAXPREGUNTAPADRE(
   pCOD_HOGAR IN VARCHAR2,
    pIDTEMA IN NUMBER,
 cur_OUT OUT SYS_REFCURSOR
  )
  AS
BEGIN
  --NR-2020-05  
  OPEN cur_OUT FOR
  SELECT MAX(t.pre_idpreguntapadre) AS padre, 
         MAX(pr.ixp_orden) AS ORDEN,
         MAX(t.pre_idpregunta) AS preguntaactual
   FROM gic_n_preguntasderivadas t,
        gic_n_instrumentoxpreg pr 
   WHERE pr.pre_idpregunta= t.pre_idpreguntapadre
     AND t.hog_codigo= pCOD_HOGAR  
     AND t.tem_idtema = pIDTEMA 
     AND t.guardado=0;
  
  EXCEPTION  WHEN OTHERS THEN
   SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_GET_MAXPREGUNTAPADRE','');
   SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_GET_MAXPREGUNTAPADRE','');
  
  END SP_GET_MAXPREGUNTAPADRE;

--VALIDAR QUE CAPITULOS ESTAN TERMINADOS, NO TERMIANDOS O NO EMPEZADOS
PROCEDURE SP_VALIDARTEMASINGRESO(
  pCOD_HOGAR IN VARCHAR2,
   cur_OUT OUT SYS_REFCURSOR
  )
   AS
BEGIN
  OPEN cur_OUT FOR
  --NR 2020-05
    SELECT te.tem_idtema,
    CASE WHEN t.idtema <> 0 
         THEN 
    CASE WHEN t.cumple <> 0 AND t.cumple IS NOT NULL  
         THEN  'T' ELSE 'NT' END ELSE 'NE' 
    END  AS val
    FROM gic_tema TE,
        (SELECT DISTINCT COALESCE(pre.tem_idtema,0) AS idtema,
                COALESCE(TER.TEM_IDTEMA,0) AS cumple
           FROM gic_n_respuestasencuesta t,
                gic_n_instrumentoxresp re,    
                gic_n_respuestas res,        
                gic_n_instrumentoxpreg pre,  
                gic_n_capitulos_ter ter     
          WHERE re.res_idrespuesta=t.res_idrespuesta
            AND res.res_idrespuesta = re.res_idrespuesta
            AND pre.pre_idpregunta = res.pre_idpregunta
            AND pre.tem_idtema = ter.tem_idtema(+)
            AND ter.hog_codigo= pCOD_HOGAR
            AND t.hog_codigo = pCOD_HOGAR) T
    WHERE   te.tem_idtema = t.idtema (+)
    ORDER BY te.tem_idtema;
    
  Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_VALIDARTEMASINGRESO','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_VALIDARTEMASINGRESO','');
  
  END SP_VALIDARTEMASINGRESO;

PROCEDURE SP_GET_MIEMBROSHOGAR(
 pCOD_HOGAR IN VARCHAR2,
   cur_OUT OUT gic_cursor.cursor_select
  )
   AS
BEGIN
  OPEN cur_OUT FOR
  select pe.per_primernombre|| ' ' || pe.per_segundonombre || ' ' || pe.per_primerapellido || ' ' || pe.per_segundoapellido as nombre ,
ho.hog_codigoencuesta,  mh.per_idpersona , mh.per_encuestada
from gic_miembros_hogar mh
join gic_hogar ho on ho.hog_codigo=mh.hog_codigo
join gic_persona pe on pe.per_idpersona =mh.per_idpersona
WHERE ho.hog_codigoencuesta=pCOD_HOGAR;

Exception  when others then
SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_GET_MIEMBROSHOGAR','');
SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_GET_MIEMBROSHOGAR','');
  
 END SP_GET_MIEMBROSHOGAR;

--BORRADO RESPUESTAS POR PREGUNTA, FILTRADOS POR HOGAR, ID PERSONA Y ID RESPUESTA  CUANDO SE VA A REALIZAR LA INSERCION DE UNA NUEVA RESPUESTA.
 PROCEDURE SP_BORRADORESPUESTAS
(
pcod_hogar in varchar2,
pins_IdInstrumento in number,
pId_Respuesta in number,
pper_idPersona in number
)

AS
BEGIN

--borra las respuestas de la pregunta

for cur_act in (SELECT T.RES_IDRESPUESTA FROM
                GIC_N_RESPUESTASENCUESTA T
                JOIN GIC_N_RESPUESTAS RE ON RE.RES_IDRESPUESTA=T.RES_IDRESPUESTA
                JOIN GIC_N_PREGUNTAS PR ON PR.PRE_IDPREGUNTA=RE.PRE_IDPREGUNTA
                WHERE T.HOG_CODIGO=pcod_hogar
                AND PER_IDPERSONA=pper_idPersona
                AND INS_IDINSTRUMENTO=pins_IdInstrumento 
                --AND PR.PRE_IDPREGUNTA=(SELECT PRE_IDPREGUNTA FROM GIC_N_RESPUESTAS R WHERE R.RES_IDRESPUESTA=pId_Respuesta)
                AND PR.PRE_IDPREGUNTA=pId_Respuesta) loop


       DELETE FROM GIC_N_RESPUESTASENCUESTA
       where HOG_CODIGO=pcod_hogar
       and PER_IDPERSONA=pper_idPersona
       and INS_IDINSTRUMENTO=pins_IdInstrumento
       and RES_IDRESPUESTA=cur_act.res_idrespuesta;
end loop;  
COMMIT;     


 Exception  when others then
 SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_BORRADORESPUESTAS','');
 SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_BORRADORESPUESTAS','');

END SP_BORRADORESPUESTAS;

--SIGUIENTE PREGUNTA CONSULTA
PROCEDURE SP_BUSCAR_SIGCONSULTA(
  pHOG_CODIGO IN VARCHAR2,
  pID_TEMA IN NUMBER,
  pINS_IDINSTRUMENTO IN NUMBER,
  pID_PREGUNTA IN NUMBER,
  cur_OUT OUT GIC_CURSOR.cursor_select
  )
  AS
  pCont_Preg number;
  BEGIN

    IF pID_PREGUNTA = 0 THEN
         SELECT MIN(IXP_ORDEN)-1 INTO pCont_Preg  FROM gic_n_respuestasencuesta G
    JOIN gic_n_respuestas A
    ON a.RES_IDRESPUESTA=G.RES_IDRESPUESTA
    LEFT JOIN  GIC_N_INSTRUMENTOXPREG C
    ON A.PRE_IDPREGUNTA=C.PRE_IDPREGUNTA
    WHERE TEM_IDTEMA=pID_TEMA
    AND G.HOG_CODIGO=pHOG_CODIGO
    AND G.INS_IDINSTRUMENTO=pINS_IDINSTRUMENTO;
    ELSE
           SELECT PR.IXP_ORDEN INTO pCont_Preg
            FROM  GIC_N_INSTRUMENTOXPREG PR
            WHERE PR.PRE_IDPREGUNTA=pID_PREGUNTA
            AND PR.TEM_IDTEMA=pID_TEMA;
    END IF;

    OPEN cur_OUT FOR
       SELECT I.PRE_IDPREGUNTA, I.PRE_PREGUNTA, I.PRE_TIPOPREGUNTA, I.PRE_TIPOCAMPO, J.HOG_CODIGO, J.PER_IDPERSONA,
J.PER_PRIMERNOMBRE, J.PER_SEGUNDONOMBRE, J.PER_PRIMERAPELLIDO, J.PER_SEGUNDOAPELLIDO,
CASE WHEN I.VALIDACION_PERSONA = 1  THEN I.VALIDACION_PERSONA ELSE 0 END AS VALIDACION_PERSONA , 'I' ORDENPRIORIDAD,
I.IXP_ORDEN_PREG AS IXP_ORDEN FROM
(select hog_codigo, d.per_idpersona, per_primernombre, per_segundonombre, per_primerapellido, per_segundoapellido

            from gic_miembros_hogar d, gic_persona e
            WHERE d.per_idpersona=e.per_idpersona
                  AND HOG_CODIGO=pHOG_CODIGO
          ) J
  JOIN
(SELECT DISTINCT A.PRE_IDPREGUNTA, A.PRE_PREGUNTA, C.PRE_TIPOPREGUNTA, C.PRE_TIPOCAMPO, G.HOG_CODIGO, G.PER_IDPERSONA,
H.PER_PRIMERNOMBRE, H.PER_SEGUNDONOMBRE, H.PER_PRIMERAPELLIDO, H.PER_SEGUNDOAPELLIDO,
1 VALIDACION_PERSONA, 'I' ORDENPRIORIDAD,
C.IXP_ORDEN IXP_ORDEN_PREG
FROM gic_n_preguntas A
LEFT JOIN  gic_n_respuestas B
ON A.PRE_IDPREGUNTA=B.PRE_IDPREGUNTA
LEFT JOIN  GIC_N_INSTRUMENTOXPREG C
ON A.PRE_IDPREGUNTA=C.PRE_IDPREGUNTA
LEFT JOIN  GIC_N_VALXINSTRUMENTO F
ON A.PRE_IDPREGUNTA=F.PRE_IDPREGUNTA
LEFT JOIN  gic_n_respuestasencuesta G
ON B.RES_IDRESPUESTA=G.RES_IDRESPUESTA
LEFT JOIN (select hog_codigo, d.per_idpersona, per_primernombre, per_segundonombre, per_primerapellido, per_segundoapellido

            from gic_miembros_hogar d, gic_persona e
            WHERE d.per_idpersona=e.per_idpersona
                  AND HOG_CODIGO=pHOG_CODIGO
          ) H
ON G.PER_IDPERSONA=H.PER_IDPERSONA
WHERE C.TEM_IDTEMA=pID_TEMA AND G.HOG_CODIGO=pHOG_CODIGO
AND C.IXP_ORDEN=(SELECT MIN(IXP_ORDEN) FROM gic_n_respuestasencuesta G
JOIN gic_n_respuestas A
ON a.RES_IDRESPUESTA=G.RES_IDRESPUESTA
LEFT JOIN  GIC_N_INSTRUMENTOXPREG C
ON A.PRE_IDPREGUNTA=C.PRE_IDPREGUNTA
WHERE TEM_IDTEMA= pID_TEMA
AND G.HOG_CODIGO=pHOG_CODIGO
 AND IXP_ORDEN>pCont_Preg)
AND C.INS_IDINSTRUMENTO=pINS_IDINSTRUMENTO
) I
ON J.PER_IDPERSONA = I.PER_IDPERSONA ORDER BY I.PRE_IDPREGUNTA;

Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_BUSCAR_SIGCONSULTA','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_BUSCAR_SIGCONSULTA','');
       
END  SP_BUSCAR_SIGCONSULTA;

--BUSCA LA PREGUNTA ANTERIORMENTE GUARDADA CONSULTA
PROCEDURE SP_BUSCAR_ANTPREGUNCONSULTA(
  pHOG_CODIGO IN VARCHAR2,
  pID_TEMA IN NUMBER,
  pINS_IDINSTRUMENTO IN NUMBER,
  pID_PREGUNTA IN NUMBER,
  cur_OUT OUT GIC_CURSOR.cursor_select
  )
  AS
  pCont_Preg number;
   pper_idPreguntaPadre number;
  BEGIN

    IF pID_PREGUNTA = 0 THEN
         SELECT MAX(IXP_ORDEN)+1 INTO pCont_Preg  FROM gic_n_respuestasencuesta G
    JOIN gic_n_respuestas A
    ON a.RES_IDRESPUESTA=G.RES_IDRESPUESTA
    LEFT JOIN  GIC_N_INSTRUMENTOXPREG C
    ON A.PRE_IDPREGUNTA=C.PRE_IDPREGUNTA
    WHERE TEM_IDTEMA=pID_TEMA
    AND G.HOG_CODIGO=pHOG_CODIGO
    AND G.INS_IDINSTRUMENTO=pINS_IDINSTRUMENTO;
    ELSE
           SELECT PR.IXP_ORDEN INTO pCont_Preg
            FROM  GIC_N_INSTRUMENTOXPREG PR
            WHERE PR.PRE_IDPREGUNTA=pID_PREGUNTA
            AND PR.TEM_IDTEMA=pID_TEMA;
    END IF;

    OPEN cur_OUT FOR
       SELECT I.PRE_IDPREGUNTA, I.PRE_PREGUNTA, I.PRE_TIPOPREGUNTA, I.PRE_TIPOCAMPO, J.HOG_CODIGO, J.PER_IDPERSONA,
J.PER_PRIMERNOMBRE, J.PER_SEGUNDONOMBRE, J.PER_PRIMERAPELLIDO, J.PER_SEGUNDOAPELLIDO,
CASE WHEN I.VALIDACION_PERSONA = 1  THEN I.VALIDACION_PERSONA ELSE 0 END AS VALIDACION_PERSONA , 'I' ORDENPRIORIDAD,
I.IXP_ORDEN_PREG AS IXP_ORDEN FROM
(select hog_codigo, d.per_idpersona, per_primernombre, per_segundonombre, per_primerapellido, per_segundoapellido

            from gic_miembros_hogar d, gic_persona e
            WHERE d.per_idpersona=e.per_idpersona
                  AND HOG_CODIGO=pHOG_CODIGO
          ) J
  JOIN
(SELECT DISTINCT A.PRE_IDPREGUNTA, A.PRE_PREGUNTA, C.PRE_TIPOPREGUNTA, C.PRE_TIPOCAMPO, G.HOG_CODIGO, G.PER_IDPERSONA,
H.PER_PRIMERNOMBRE, H.PER_SEGUNDONOMBRE, H.PER_PRIMERAPELLIDO, H.PER_SEGUNDOAPELLIDO,
1 VALIDACION_PERSONA, 'I' ORDENPRIORIDAD,
C.IXP_ORDEN IXP_ORDEN_PREG
FROM gic_n_preguntas A
LEFT JOIN  gic_n_respuestas B
ON A.PRE_IDPREGUNTA=B.PRE_IDPREGUNTA
LEFT JOIN  GIC_N_INSTRUMENTOXPREG C
ON A.PRE_IDPREGUNTA=C.PRE_IDPREGUNTA
LEFT JOIN  GIC_N_VALXINSTRUMENTO F
ON A.PRE_IDPREGUNTA=F.PRE_IDPREGUNTA
LEFT JOIN  gic_n_respuestasencuesta G
ON B.RES_IDRESPUESTA=G.RES_IDRESPUESTA
LEFT JOIN (select hog_codigo, d.per_idpersona, per_primernombre, per_segundonombre, per_primerapellido, per_segundoapellido
           from gic_miembros_hogar d, gic_persona e
           WHERE d.per_idpersona=e.per_idpersona
           AND HOG_CODIGO=pHOG_CODIGO
          ) H
          ON G.PER_IDPERSONA=H.PER_IDPERSONA
          WHERE C.TEM_IDTEMA=pID_TEMA AND G.HOG_CODIGO=pHOG_CODIGO
          AND C.IXP_ORDEN=(SELECT MAX(IXP_ORDEN) FROM gic_n_respuestasencuesta G
          JOIN gic_n_respuestas A
          ON a.RES_IDRESPUESTA=G.RES_IDRESPUESTA
          LEFT JOIN  GIC_N_INSTRUMENTOXPREG C
          ON A.PRE_IDPREGUNTA=C.PRE_IDPREGUNTA
          WHERE TEM_IDTEMA= pID_TEMA
          AND G.HOG_CODIGO=pHOG_CODIGO
           AND IXP_ORDEN<pCont_Preg)
          AND C.INS_IDINSTRUMENTO=pINS_IDINSTRUMENTO
          ) I
          ON J.PER_IDPERSONA = I.PER_IDPERSONA ORDER BY I.PRE_IDPREGUNTA
        ;

    SELECT PRE_IDPREGUNTA into pper_idPreguntaPadre
    FROM GIC_N_INSTRUMENTOXPREG C WHERE TEM_IDTEMA=pID_TEMA
    AND C.IXP_ORDEN=(SELECT MAX(IXP_ORDEN) FROM gic_n_respuestasencuesta G
    JOIN gic_n_respuestas A
    ON a.RES_IDRESPUESTA=G.RES_IDRESPUESTA
    LEFT JOIN  GIC_N_INSTRUMENTOXPREG C
    ON A.PRE_IDPREGUNTA=C.PRE_IDPREGUNTA
    WHERE TEM_IDTEMA= pID_TEMA
    AND G.HOG_CODIGO=pHOG_CODIGO
    AND IXP_ORDEN<pCont_Preg);
    
  Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_BUSCAR_ANTPREGUNCONSULTA','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_BUSCAR_ANTPREGUNCONSULTA','');
  
END  SP_BUSCAR_ANTPREGUNCONSULTA;

FUNCTION FN_VERIFICARRESPUESTA( pHOG_CODIGO IN VARCHAR2,
  pINS_IDINSTRUMENTO IN NUMBER,
  pID_RESPUESTA IN NUMBER,
  pID_PERSONA IN NUMBER,
  PDepartamento IN NVARCHAR2)
  RETURN BOOLEAN IS RESULTADO BOOLEAN;
  Existe NUMBER;
 BEGIN
   IF  FN_TRAETIPOCAMPO(pID_RESPUESTA) ='MU' THEN
         SELECT count(T.RES_IDRESPUESTA) into  Existe
         FROM
         GIC_N_RESPUESTASENCUESTA T
         JOIN GIC_N_RESPUESTAS RE ON RE.RES_IDRESPUESTA=T.RES_IDRESPUESTA
         WHERE T.HOG_CODIGO=pHOG_CODIGO
         AND PER_IDPERSONA=pID_PERSONA
         AND INS_IDINSTRUMENTO=pINS_IDINSTRUMENTO AND T.RES_IDRESPUESTA=pID_RESPUESTA;
   ELSE
         SELECT count(T.RES_IDRESPUESTA) into  Existe
         FROM
         GIC_N_RESPUESTASENCUESTA T
         JOIN GIC_N_RESPUESTAS RE ON RE.RES_IDRESPUESTA=T.RES_IDRESPUESTA
         WHERE T.HOG_CODIGO=pHOG_CODIGO
         AND PER_IDPERSONA=pID_PERSONA
         AND INS_IDINSTRUMENTO=pINS_IDINSTRUMENTO AND T.RES_IDRESPUESTA=pID_RESPUESTA
         AND T.RXP_TEXTORESPUESTA=PDepartamento;
   END IF;

   IF EXISTE > 0 THEN
     RESULTADO := TRUE;
     ELSE
       RESULTADO := FALSE;
   END IF;
   return(RESULTADO);
   
  Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'FN_VERIFICARRESPUESTA','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'FN_VERIFICARRESPUESTA','');
  
  END FN_VERIFICARRESPUESTA;

FUNCTION FN_TRAETIPOCAMPO(pID_RESPUESTA IN NUMBER)
  RETURN NVARCHAR2 IS RESULTADO NVARCHAR2(2);
  RES NVARCHAR2(2);
   BEGIN
     SELECT  CASE WHEN PR.PRE_TIPOCAMPO = 'DP' OR PR.PRE_TIPOCAMPO = 'TE' OR PR.PRE_TIPOCAMPO='CT' OR PR.PRE_TIPOCAMPO='LT' OR PR.PRE_TIPOCAMPO = 'TA' OR PR.PRE_TIPOCAMPO = 'AT' THEN 'UN' ELSE 'MU' END AS
     INTO RES
     FROM GIC_N_RESPUESTAS RE
     JOIN GIC_N_INSTRUMENTOXPREG PR ON PR.PRE_IDPREGUNTA=RE.PRE_IDPREGUNTA
     WHERE RE.RES_IDRESPUESTA=pID_RESPUESTA;
     RESULTADO :=RES;

     RETURN RESULTADO;
     
     Exception  when others then
     SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'FN_TRAETIPOCAMPO','');
     SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'FN_TRAETIPOCAMPO','');
  
     END FN_TRAETIPOCAMPO;
    --COMPRUEBA SI LA ENCUESTA  YA ESTA FINALIZADA
PROCEDURE SP_GET_ENCUESTAFINALIZADO

(
  pCOD_HOGAR IN VARCHAR2,
 cur_OUT OUT gic_cursor.cursor_select
)
AS
BEGIN
  OPEN cur_OUT FOR
 SELECT COUNT(TD.HOG_CODIGO) AS TOTAL FROM GIC_N_ENCUESTA_TER TD
    WHERE TD.HOG_CODIGO=pCOD_HOGAR;
    
  Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_GET_ENCUESTAFINALIZADO','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_GET_ENCUESTAFINALIZADO','');
  
END SP_GET_ENCUESTAFINALIZADO;

--COMPRUEBA SI YA SE LLENARON LOS TRES PRIMEROS CAPITULOS PARA HABIITAR LOS DEMAS
PROCEDURE SP_GET_HABILITARCAPITULOS

(
  pCOD_HOGAR IN VARCHAR2,
 cur_OUT OUT SYS_REFCURSOR
)
AS
BEGIN
  OPEN cur_OUT FOR
--NR 2020-05
SELECT COUNT(1) AS TOTAL  
  FROM gic_n_capitulos_ter TER
 WHERE TER.TEM_IDTEMA IN (1,2,3) 
  AND TER.HOG_CODIGO = pCOD_HOGAR;

Exception  when others then
SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_GET_HABILITARCAPITULOS','');
SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_GET_HABILITARCAPITULOS','');
  
END SP_GET_HABILITARCAPITULOS;

--BORRAR NOMBRES VACIOS POR PERSONA CUANDO NO SE TRAE INFORMACION DEL  PRE  CARGUE INICIAL.
PROCEDURE SP_BORRARNOMVACIOS
(phogCodigo IN VARCHAR2,
pidRespuesta IN NUMBER,
pIdPersona IN NUMBER,
pIdInstrumento IN NUMBER)
    AS
  BEGIN
     DELETE FROM GIC_N_RESPUESTASENCUESTA T WHERE T.HOG_CODIGO=phogCodigo AND T.RES_IDRESPUESTA=pidRespuesta
     AND T.PER_IDPERSONA=pIdPersona AND T.INS_IDINSTRUMENTO=pIdInstrumento;
    COMMIT;
    
  Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_BORRARNOMVACIOS','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_BORRARNOMVACIOS','');
  
    END   SP_BORRARNOMVACIOS;

--CONCATENAR MIEMBROS HOGAR ENCUESTA POR COIDGO
FUNCTION FN_GET_MIEXHOGAR(pCODIGO IN VARCHAR2)
   RETURN VARCHAR2
IS Result NVARCHAR2(5000);
  MIEMBROS NVARCHAR2(5000);
  CONTEO NUMBER;
BEGIN
 SELECT
COUNT(PERS.PER_IDPERSONA) INTO CONTEO
FROM GIC_MIEMBROS_HOGAR MI
JOIN GIC_PERSONA PERS ON PERS.PER_IDPERSONA=MI.PER_IDPERSONA
WHERE MI.HOG_CODIGO=pCODIGO;

IF CONTEO > 0 THEN
FOR CUR_DATOS IN ( SELECT
CONCAT(CONCAT(CONCAT(PERS.PER_PRIMERNOMBRE,' '),PERS.PER_SEGUNDONOMBRE),CONCAT(CONCAT(CONCAT(' ', PERS.PER_PRIMERAPELLIDO),' ' ),PERS.PER_SEGUNDOAPELLIDO)) AS NOMBRES
FROM GIC_MIEMBROS_HOGAR MI
JOIN GIC_PERSONA PERS ON PERS.PER_IDPERSONA=MI.PER_IDPERSONA
WHERE MI.HOG_CODIGO=pCODIGO)
  LOOP
    IF CUR_DATOS.NOMBRES IS NOT NULL   THEN
   MIEMBROS :=CONCAT(MIEMBROS, CONCAT(CUR_DATOS.NOMBRES,','));
   END IF;
  END LOOP;
  MIEMBROS :=SUBSTR(MIEMBROS,1,length(MIEMBROS)-1) ;
    END IF;
  Result :=MIEMBROS;
  RETURN Result;
  
  Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'FN_GET_MIEXHOGAR','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'FN_GET_MIEXHOGAR','');
  
END FN_GET_MIEXHOGAR;

--DEVUELVE TODOS LOS CODIGOS ASOCIADOS A ESE USUARIO
PROCEDURE SP_REPORTE_MIEMBROSXCODIGO

(
  pUSUARIO IN VARCHAR2,
 cur_OUT OUT gic_cursor.cursor_select
)
AS
BEGIN
  OPEN cur_OUT FOR
SELECT DISTINCT T.HOG_CODIGOENCUESTA AS CODIGO,
GIC_N_CARACTERIZACION.FN_GET_MIEXHOGAR(T.HOG_CODIGO) AS MIEMBROS, T.USU_FECHACREACION AS FECHACREACION, T.USU_USUARIOCREACION  AS USUARIO,
CONCAT(CONCAT(US.USU_PRIMERNOMBRE,' '),US.USU_PRIMERAPELLIDO) AS NOMBRES,
--CASE WHEN AC.ARC_URL IS NOT NULL  THEN '<a href= '''||AC.ARC_URL||''' target=''_blank'' > Colilla</a>'  ELSE '' END  AS COLILLA
CASE WHEN AC.ARC_URL IS NOT NULL  THEN '<a href="file://///172.20.200.48/Archivos/Colillas%20hogares/EN5T8.pdF" target=''_blank'' > Colilla</a>'  ELSE '' END  AS COLILLA
FROM GIC_HOGAR T
JOIN GIC_USUARIO US ON US.USU_USUARIO=T.USU_USUARIOCREACION
LEFT JOIN GIC_ARCHIVOCOLILLA AC ON AC.HOG_CODIGO=T.HOG_CODIGO
WHERE T.USU_USUARIOCREACION=pUSUARIO
AND GIC_N_CARACTERIZACION.FN_GET_MIEXHOGAR(T.HOG_CODIGO) IS NOT NULL
AND T.HOG_CODIGOENCUESTA IS NOT NULL
 ORDER BY  T.USU_FECHACREACION DESC;
 
 Exception  when others then
 SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_REPORTE_MIEMBROSXCODIGO','');
 SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_REPORTE_MIEMBROSXCODIGO','');
  
END SP_REPORTE_MIEMBROSXCODIGO;

--DEVUELVE TODOS LOS CODIGOS ASOCIADOS A ESE USUARIO
PROCEDURE SP_REPORTE_MIEMBROSXCODIGO_2

(
  pUSUARIO IN VARCHAR2,
 cur_OUT OUT gic_cursor.cursor_select
)
AS
  
BEGIN
  
  OPEN cur_OUT FOR
       SELECT DISTINCT T.HOG_CODIGO  AS CODIGO, 
                      GIC_N_CARACTERIZACION.FN_GET_MIEXHOGAR(T.HOG_CODIGO) AS "MIEMBROS DEL HOGAR", T.USU_FECHACREACION AS "FECHA DE CREACION", T.ESTADO,
                      CASE WHEN AC.ARC_URL IS NOT NULL  THEN AC.ARC_URL  ELSE '' END  AS SOPORTE 
      FROM GIC_HOGAR T
      LEFT JOIN GIC_ARCHIVOCOLILLA AC ON AC.HOG_CODIGO=T.HOG_CODIGO
      WHERE T.USU_USUARIOESTADO=pUSUARIO
            AND GIC_N_CARACTERIZACION.FN_GET_MIEXHOGAR(T.HOG_CODIGO) IS NOT NULL
            AND T.HOG_CODIGOENCUESTA IS NOT NULL
            AND T.ESTADO NOT IN ('ERROR','PRUEBA')
      ORDER BY  T.USU_FECHACREACION DESC;
      
  Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_REPORTE_MIEMBROSXCODIGO_2','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_REPORTE_MIEMBROSXCODIGO_2','');
  
END SP_REPORTE_MIEMBROSXCODIGO_2;

--DEVUELVE LA EDAD  A PARTIR  DE LA FECHA NACIMIENTO POR PERSONA
FUNCTION FN_GET_EDADXPERSONA(pIDPERSONA IN INTEGER, pCODHOGAR IN VARCHAR2) RETURN INTEGER
 IS RESULT INTEGER;
 PEDAD NUMBER;

 BEGIN
  SELECT 
  floor(floor(months_between(sysdate,TO_DATE(res.rxp_textorespuesta,'YYYY-MM-DD')))/12)
  AS edad INTO PEDAD
FROM gic_n_respuestasencuesta res
WHERE res.res_idrespuesta=78 AND res.hog_codigo=pCODHOGAR AND res.per_idpersona=pIDPERSONA;
RESULT :=PEDAD;
  RETURN RESULT ;
-- excepcion en caso de otro error;
   Exception when others then
   return 0;
        

  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'FN_GET_EDADXPERSONA','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'FN_GET_EDADXPERSONA','');
  
  END  FN_GET_EDADXPERSONA;

--INSERTA ARCHIVO COLILLA ASOCIADO A UN CODIGO DE HOGAR.
PROCEDURE SP_INSERTA_ARCHIVO
  (
  pHOG_CODIGO IN VARCHAR2,
  pARC_URL IN VARCHAR2,
  pUSU_CREACION IN VARCHAR2
  )
 AS
BEGIN

 DELETE FROM GIC_ARCHIVOCOLILLA T WHERE T.HOG_CODIGO=pHOG_CODIGO;
 COMMIT;
  INSERT INTO GIC_ARCHIVOCOLILLA
  (HOG_CODIGO, ARC_URL, USU_USUARIOCREACION, USU_FECHACREACION)
  VALUES
  (pHOG_CODIGO,pARC_URL,pUSU_CREACION, SYSDATE);
  COMMIT;
  
  Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_INSERTA_ARCHIVO','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_INSERTA_ARCHIVO','');  
END SP_INSERTA_ARCHIVO;

--INSERTAR Y DEVUELVE  HOGAR 
FUNCTION GET_CODIGOHOGAR
  (
    USUA_CREACION IN NVARCHAR2,
    ID_USUARIO IN INTEGER
  )
  RETURN VARCHAR2
IS Result VARCHAR2(20);
  CODIGOENCUESTA VARCHAR2(20);
  idPerfil number:=0;
  BEGIN

    CODIGOENCUESTA := GIC_N_CARACTERIZACION.FN_GET_CODIGOENCUESTA;
    SELECT MAX(pu.idperfil) INTO idPerfil
    FROM adminusuarios.perfilusuario@DBLINK_VIVANTO pu where pu.idusuario = ID_USUARIO and pu.idperfil in (SELECT PE.IDPERFIL FROM adminusuarioS.PERFIL@DBLINK_VIVANTO PE WHERE PE.IDAPLICACION  IN (309));
    
    SELECT COUNT(pu.idperfil) INTO idPerfil
    FROM adminusuarios.perfilusuario@DBLINK_VIVANTO pu where pu.idusuario = ID_USUARIO and pu.idperfil in (SELECT PE.IDPERFIL FROM adminusuarioS.PERFIL@DBLINK_VIVANTO PE WHERE PE.IDAPLICACION  IN (309));
    
    IF idPerfil > 0 THEN
      
    SELECT MAX(pu.idperfil) INTO idPerfil
    FROM adminusuarios.perfilusuario@DBLINK_VIVANTO pu where pu.idusuario = ID_USUARIO and pu.idperfil in (SELECT PE.IDPERFIL FROM adminusuarioS.PERFIL@DBLINK_VIVANTO PE WHERE PE.IDAPLICACION  IN (309));
    
    INSERT INTO GIC_HOGAR VALUES(0,TRIM(CODIGOENCUESTA),USUA_CREACION,ID_USUARIO,SYSDATE,2,CODIGOENCUESTA,'MANUAL',SYSDATE,USUA_CREACION,idPerfil);
    COMMIT;
    
    ELSE
    
    INSERT INTO GIC_HOGAR VALUES(0,TRIM(CODIGOENCUESTA),USUA_CREACION,ID_USUARIO,SYSDATE,2,CODIGOENCUESTA,'MANUAL',SYSDATE,USUA_CREACION,0);
    COMMIT;
    
    END IF;
    
    
 Result := CODIGOENCUESTA;
 return  Result;
 
 Exception  when others then
 SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'GET_CODIGOHOGAR','');
 SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'GET_CODIGOHOGAR','');
  
 END GET_CODIGOHOGAR;
 --CARGA AUTOCOMPLETAR TEXTOS FILTRADOS
PROCEDURE SP_CARGAUTOCOMPLETAR(pIDPREGUNTA IN INTEGER,pFILTRO IN NVARCHAR2, cur_OUT OUT ACCIONSOCIAL.cursor_select)
  AS
  pCONSULTA  VARCHAR2(2000);
  BEGIN
   select REPLACE(T.CONSULTA,'@FILTRO',pFILTRO) INTO pCONSULTA from GIC_N_CONFIGAUTO t WHERE t.pre_idpregunta=pIDPREGUNTA;

    OPEN cur_OUT  FOR pCONSULTA;
  --  EXECUTE IMMEDIATE  pCONSULTA;

  Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_CARGAUTOCOMPLETAR','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_CARGAUTOCOMPLETAR','');
  
  END SP_CARGAUTOCOMPLETAR;

   --CARGA AUTOCOMPLETAR TEXTOS TOTAL
PROCEDURE SP_CARGAUTOCOMPLETARTOTAL(pIDPREGUNTA IN INTEGER, CURSOR_OUT OUT ACCIONSOCIAL.cursor_select)
  AS
  pCONSULTA  VARCHAR2(2000);
  BEGIN
   --select REPLACE(T.CONSULTA,'@FILTRO',pFILTRO) INTO pCONSULTA from GIC_N_CONFIGAUTO t WHERE t.pre_idpregunta=pIDPREGUNTA;
     select T.CONSULTA INTO pCONSULTA from GIC_N_CONFIGAUTO t WHERE t.pre_idpregunta=pIDPREGUNTA AND T.TIPO=1;

    OPEN CURSOR_OUT FOR pCONSULTA;
  --  EXECUTE IMMEDIATE  pCONSULTA;
Exception
        when others then
           OPEN CURSOR_OUT FOR
          select t.dummy as DATO from dual t WHERE  1=1;
    

          SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_CARGAUTOCOMPLETARTOTAL','');
          SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_CARGAUTOCOMPLETARTOTAL','');      
  
  END SP_CARGAUTOCOMPLETARTOTAL;

FUNCTION FN_VALIDARXRESPUESTA(pHOG_CODIGO IN VARCHAR2, pID_PREGUNTA IN NUMBER, pID_RESPUESTA IN NUMBER,  pID_PERSONA IN NUMBER, pINS_IDINSTRUMENTO IN NUMBER)
 RETURN NUMBER is
 Val_RES VARCHAR2(2);
 CONDICION VARCHAR2(2000);
 BUSRESPUESTAS VARCHAR2(2000);
 RESPCONTESTADAS VARCHAR2(2000);
 RESULTADO VARCHAR2(2000);
 CONTEO NUMBER;
 Result NUMBER;
  BEGIN
    Result :=0;

      SELECT COUNT(1) INTO CONTEO FROM GIC_N_VALIDADORESXRESPUESTA WHERE IDPREGUNTA=pID_PREGUNTA;
      
      IF CONTEO  = 1 THEN
      SELECT CONDICION,IDRESPUESTA INTO CONDICION,BUSRESPUESTAS  FROM GIC_N_VALIDADORESXRESPUESTA WHERE IDPREGUNTA=pID_PREGUNTA;

      RESULTADO := 'SELECT LISTAGG(res_idrespuesta, '','') WITHIN GROUP (ORDER BY res_idrespuesta)
      from gic_n_respuestasencuesta t WHERE  t.res_idrespuesta in (' || BUSRESPUESTAS || ') AND
      t.hog_codigo =''' || pHOG_CODIGO || ''' AND t.per_idpersona =' || pID_PERSONA;

      EXECUTE IMMEDIATE RESULTADO INTO RESPCONTESTADAS;

      CONDICION := REPLACE (CONDICION,'CADENA',RESPCONTESTADAS);

      RESULTADO := 'SELECT CASE WHEN ' || CONDICION || ' THEN 1 ELSE 0 END FROM DUAL';
      EXECUTE IMMEDIATE RESULTADO INTO BUSRESPUESTAS;

      Result :=BUSRESPUESTAS;        
      END IF;

  RETURN Result;
  
  Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'FN_VALIDARXRESPUESTA','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'FN_VALIDARXRESPUESTA','');
  
  END FN_VALIDARXRESPUESTA;

--VALIDAR RESPUESTA DE AUTOCOMPELTAR
PROCEDURE SP_VALRESAUTOCOMPLETAR(TEXTO IN VARCHAR2, CURSOR_OUT OUT ACCIONSOCIAL.cursor_select)
AS
  BEGIN
    OPEN CURSOR_OUT FOR
    SELECT COUNT(1) AS TOTAL 
     FROM gic_ocupacion T
    WHERE  concaT(concat(T.OCUPACION,' - '),T.CODIGO) = TEXTO;
  
  EXCEPTION  WHEN OTHERS THEN
   SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_VALRESAUTOCOMPLETAR','');
   SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_VALRESAUTOCOMPLETAR','');
  
  END SP_VALRESAUTOCOMPLETAR;


FUNCTION FN_VALIDARXPREGUNTA(pHOG_CODIGO IN VARCHAR2, pID_PREGUNTA IN NUMBER, pID_PERSONA IN NUMBER, pINS_IDINSTRUMENTO IN NUMBER)
 RETURN NUMBER is
 Val_RES VARCHAR2(2);
 CONDICION VARCHAR2(2000);
 BUSRESPUESTAS VARCHAR2(500);
 RESPCONTESTADAS VARCHAR2(500);
 RESULTADO VARCHAR2(1000);
 Result NUMBER;
  BEGIN
    Result :=0;

      SELECT CONDICION,IDRESPUESTA INTO CONDICION,BUSRESPUESTAS  FROM GIC_N_VALIDADORESXRESPUESTA WHERE IDPREGUNTA=pID_PREGUNTA;

      RESULTADO := 'SELECT LISTAGG(res_idrespuesta, '','') WITHIN GROUP (ORDER BY res_idrespuesta)
      from gic_n_respuestasencuesta t WHERE  t.res_idrespuesta in (' || BUSRESPUESTAS || ') AND
      t.hog_codigo =''' || pHOG_CODIGO || ''' AND t.per_idpersona =' || pID_PERSONA;

      EXECUTE IMMEDIATE RESULTADO INTO RESPCONTESTADAS;

      CONDICION := REPLACE (CONDICION,'CADENA',RESPCONTESTADAS);

      RESULTADO := 'SELECT CASE WHEN ' || CONDICION || ' THEN 1 ELSE 0 END FROM DUAL';
      EXECUTE IMMEDIATE RESULTADO INTO BUSRESPUESTAS;

      Result :=BUSRESPUESTAS;

  RETURN Result;
  
  Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'FN_VALIDARXPREGUNTA','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'FN_VALIDARXPREGUNTA','');
  
  END FN_VALIDARXPREGUNTA;

--BORRADO VALIDADORES
PROCEDURE SP_BORRADOVALIDADORES
(
pcod_hogar in varchar2,
pins_IdInstrumento in number,
pId_Pregunta in number,
pper_idPersona in number
)

AS
BEGIN

 FOR cur_OUT IN
            (select res.val_idvalidador, res.val_idvalidador_def from gic_n_respuestas r
join gic_n_instrumentoxresp res on res.res_idrespuesta= r.res_idrespuesta
WHERE r.pre_idpregunta =pId_Pregunta AND res.val_idvalidador is not null
            )
 LOOP
--borra las respuestas de la pregunta
       delete from  gic_n_validadoresxpersona t WHERE t.hog_codigo=pcod_hogar
       AND t.val_idvalidador=cur_OUT.Val_Idvalidador AND t.per_idpersona=pper_idPersona ;--AND t.ins_idinstrumento=pins_IdInstrumento;
        COMMIT;
        
        
 END LOOP;
 
 
  Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_BORRADOVALIDADORES','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_BORRADOVALIDADORES','');

END SP_BORRADOVALIDADORES;


FUNCTION FN_COMPROBARVALIDACIONESRESP(pPER_IDPERSONA IN NUMBER, pRES_IDRESPUESTA IN NUMBER,pHOG_CODIGO IN VARCHAR, pINS_IDINSTRUMENTO IN NUMBER) RETURN INTEGER
  IS Result integer;
   EXISTE NUMBER;
   CONT NUMBER;
   TIENE_VAL NUMBER;
   valor varchar2(100);
   TIENE_PRE NUMBER;
   RES_VAL NUMBER(38);
BEGIN
     CONT :=0;
     Result:= 0;
-- Busca si tiene valor en el campo pre_depende
select COUNT(T.PRE_DEPENDE) into TIENE_PRE from gic_n_respuestas r, GIC_N_INSTRUMENTOXPREG T  WHERE R.PRE_IDPREGUNTA=T.PRE_IDPREGUNTA AND R.RES_IDRESPUESTA=pRES_IDRESPUESTA;
  --Busca los validadores para la pregunta
      SELECT COUNT(1) INTO TIENE_VAL FROM GIC_N_VALXINSTRUMENTORESP T
      WHERE T.RES_IDRESPUESTA IN (pRES_IDRESPUESTA) AND T.INS_IDINSTRUMENTO=pINS_IDINSTRUMENTO ;


      IF TIENE_VAL > 0 THEN
--BUSQUEDA VALIDADORES PARA LA RESPUESTA
           FOR CUR_DATOS IN ( SELECT  DISTINCT * FROM GIC_N_VALXINSTRUMENTORESP R
                                    WHERE R.RES_IDRESPUESTA IN (pRES_IDRESPUESTA) AND R.INS_IDINSTRUMENTO=pINS_IDINSTRUMENTO)

        LOOP
          --VERIFICA SI LA PERSONA TIENE VALOR PARA ESTE VALIDADOR
          SELECT COUNT(PRE_VALOR) INTO valor from GIC_N_VALIDADORESXPERSONA VP
          WHERE VP.PER_IDPERSONA=pPER_IDPERSONA AND VP.HOG_CODIGO=pHOG_CODIGO AND VAL_IDVALIDADOR=CUR_DATOS.VAL_IDVALIDADOR_PERS;

          IF VALOR>0 THEN
            --BUSCA EL VALOR DEL VALIDADOR DE LA PERSONA
            SELECT PRE_VALOR INTO valor from GIC_N_VALIDADORESXPERSONA VP
            WHERE VP.PER_IDPERSONA=pPER_IDPERSONA AND VP.HOG_CODIGO=pHOG_CODIGO AND VAL_IDVALIDADOR=CUR_DATOS.VAL_IDVALIDADOR_PERS;
            --verIFica si la persona cumple con la validacion 1 si cumple, 0 no cumple
            EXISTE := GIC_N_CARACTERIZACION.FN_VALIDARPERSONA(valor,CUR_DATOS.VAL_IDVALIDADOR);
          ELSE
            IF TIENE_PRE > 0  THEN
              EXISTE := GIC_N_CARACTERIZACION.FN_VALIDARPERSONA(valor,CUR_DATOS.VAL_IDVALIDADOR);
              ELSE
              EXISTE:= 1;
              END IF;
          END IF;
           IF EXISTE =1 THEN
            CONT :=CONT + 1;
           END IF;
       
           IF TIENE_VAL = CONT THEN
                Result:= 1;
                ELSE
                Result:= 0;
           END IF;
              
         END LOOP;
      ELSE
        Result:= 1;
      END IF;
RETURN Result;
 -- excepcion en caso de otro error;
      Exception  when others then
      return 2;
        
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'FN_COMPROBARVALIDACIONESRESP','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'FN_COMPROBARVALIDACIONESRESP','');
  
  
END FN_COMPROBARVALIDACIONESRESP;

--TRAE LAS RESPUESTAS A LA PREGUNTA
PROCEDURE SP_GET_RESPUESTASXPREMOD
   (
     pPRE_IDPREGUNTA IN NUMBER,
     pINS_IDINSTRUMENTO IN NUMBER,
     pHOG_CODIGO IN VARCHAR,
     pPER_IDPERSONA IN NUMBER,
     cur_OUT OUT GIC_CURSOR.cursor_select
    
  )
  AS
  pPRE_GENERAL NUMBER;
  pID_JEFE  NUMBER(38);
  pMULTIPLE  NUMBER;
  pRESPUESTAAN NUMBER(38);
  pOPCIONESMUL VARCHAR2(100);
  pCONSULTA VARCHAR2(2000);
  pIDTEMA NUMBER(38);
  pRESPUESTASN VARCHAR2(1000);
  pDATOVALIDADOR VARCHAR(200);
  pCANTIDAD NUMBER;
  pRESPUESTAS VARCHAR(200);
  pRESPUESTS NUMBER;
    
  BEGIN
      
  --Obtiene el id tema de la pregunta
    SELECT max(pre.tem_idtema) INTO pIDTEMA FROM 
    GIC_N_INSTRUMENTOXPREG PRE 
  WHERE PRE.PRE_IDPREGUNTA = pPRE_IDPREGUNTA;

   --ModIFicacion JAIME LOBATON, PREGUNTAS GENERALES  
  SELECT COUNT(T.PER_IDPERSONA) INTO pID_JEFE  
         FROM GIC_MIEMBROS_HOGAR T 
         WHERE T.HOG_CODIGO=pHOG_CODIGO AND T.PER_ENCUESTADA='SI';
   
  --OBTIENE ID PERSONA DEL JEFE DE HOGAR
  IF pID_JEFE > 0 THEN
      SELECT MAX(T.PER_IDPERSONA) INTO pID_JEFE  
         FROM GIC_MIEMBROS_HOGAR T 
         WHERE T.HOG_CODIGO=pHOG_CODIGO AND T.PER_ENCUESTADA='SI';
         IF pPER_IDPERSONA <>  0 THEN
            pID_JEFE := pPER_IDPERSONA  ;
                   
         END IF;
  END IF;      
  
  --VERFIFICA SI LA RESPUESTA ANTERIOR , MUESTRA OPCIONES DE RESPUESTA PREDEFINIDAS
  SELECT COUNT(1) INTO pMULTIPLE 
    FROM GIC_N_INSTRUMENTOXPREG PRE
   WHERE PRE.VAL_RESPUESTAMULTIPLE IS NOT NULL 
     AND PRE.PRE_IDPREGUNTA=pPRE_IDPREGUNTA;  
  
  --SI pMULTIPLE ES MAYOR A 0 ENTONCES OBTIENE EL VALOR DE VAL_RESPUESTAMULTIPLE
  IF  pMULTIPLE > 0 THEN    
  SELECT PRE.VAL_RESPUESTAMULTIPLE INTO pMULTIPLE FROM 
  GIC_N_INSTRUMENTOXPREG PRE WHERE PRE.VAL_RESPUESTAMULTIPLE IS NOT NULL AND PRE.PRE_IDPREGUNTA=pPRE_IDPREGUNTA;  
  END IF;
  
  
  SELECT COUNT(T.VAL_PREGUNTA_GENERAL) INTO pPRE_GENERAL  FROM GIC_N_INSTRUMENTOXPREG T WHERE T.PRE_IDPREGUNTA = pPRE_IDPREGUNTA ;
  
  
    IF  pPRE_GENERAL = 0  AND pMULTIPLE = 0  THEN
    
     OPEN cur_OUT FOR
      SELECT RI.INS_IDINSTRUMENTO, RI.RES_IDRESPUESTA, RE.RES_RESPUESTA, RI.PRE_VALIDADOR, RI.PRE_LONGCAMPO, RE.PRE_IDPREGUNTA,
      RI.PRE_VALIDADOR_MIN, RI.PRE_VALIDADOR_MAX, RI.RES_ORDENRESPUESTA, RI.PRE_CAMPOTEX, RI.RES_OBLIGATORIO, RI.RES_HABILITA, RI.RES_FINALIZA, RI.RES_AUTOCOMPLETAR
      FROM GIC_N_INSTRUMENTOXRESP RI
      JOIN GIC_N_RESPUESTAS RE ON RE.RES_IDRESPUESTA=RI.RES_IDRESPUESTA AND RE.RES_ACTIVA='SI'
      JOIN GIC_N_INSTRUMENTOXPREG PRE ON PRE.PRE_IDPREGUNTA=RE.PRE_IDPREGUNTA
      WHERE RE.PRE_IDPREGUNTA=pPRE_IDPREGUNTA AND GIC_N_CARACTERIZACION.FN_COMPROBARVALIDACIONESRESP(pID_JEFE,RE.RES_IDRESPUESTA,pHOG_CODIGO,pINS_IDINSTRUMENTO)=1;
      
    ELSIF pPRE_GENERAL > 0  THEN
    
     SP_GET_RESPUESTASVALXCONTEO(pPRE_IDPREGUNTA,pINS_IDINSTRUMENTO , pHOG_CODIGO,pID_JEFE,cur_OUT);
    
    ELSIF pMULTIPLE = 1 THEN
    --LA OPCION 1 INDICA QUE  SE DEBEN MOSTRAR LAS RESPUESTAS CONFIGURADAS ESTA CONDICION SE APLICA A LA
    --ULTIMA RESPUESTA SELECCIONADA
  
     
  SELECT  MAX(RE.RES_IDRESPUESTA)  INTO pRESPUESTAAN 
  FROM GIC_N_RESPUESTASENCUESTA RE
  JOIN GIC_N_RESPUESTAS R ON R.RES_IDRESPUESTA = RE.RES_IDRESPUESTA
  JOIN GIC_N_INSTRUMENTOXPREG PR ON PR.PRE_IDPREGUNTA = R.PRE_IDPREGUNTA
  WHERE RE.usu_fechacreacion=(SELECT MAX(usu_fechacreacion) 
  FROM GIC_N_RESPUESTASENCUESTA WHERE  HOG_CODIGO=pHOG_CODIGO)  
  AND  PR.TEM_IDTEMA =pIDTEMA AND RE.HOG_CODIGO=pHOG_CODIGO;          
  
  SELECT T.RES_RESPUESTASHABILITAR INTO pOPCIONESMUL  FROM GIC_N_INSTRUMENTOXRESP T WHERE t.res_idrespuesta=pRESPUESTAAN;
  
   pCONSULTA := ' SELECT RI.INS_IDINSTRUMENTO, RI.RES_IDRESPUESTA, RE.RES_RESPUESTA, RI.PRE_VALIDADOR, RI.PRE_LONGCAMPO, RE.PRE_IDPREGUNTA,
          RI.PRE_VALIDADOR_MIN, RI.PRE_VALIDADOR_MAX, RI.RES_ORDENRESPUESTA, RI.PRE_CAMPOTEX, RI.RES_OBLIGATORIO, RI.RES_HABILITA, RI.RES_FINALIZA, RI.RES_AUTOCOMPLETAR
          FROM GIC_N_INSTRUMENTOXRESP RI
          JOIN GIC_N_RESPUESTAS RE ON RE.RES_IDRESPUESTA=RI.RES_IDRESPUESTA AND RE.RES_ACTIVA=''SI''
          JOIN GIC_N_INSTRUMENTOXPREG PRE ON PRE.PRE_IDPREGUNTA=RE.PRE_IDPREGUNTA
          WHERE RE.PRE_IDPREGUNTA='||pPRE_IDPREGUNTA||' AND RE.RES_IDRESPUESTA IN '|| pOPCIONESMUL || '';      
                OPEN cur_OUT FOR pCONSULTA;
  
  ELSIF pMULTIPLE = 2  THEN
  --LA OPCION 2 INDICA QUE NO SE DEBEN MOSTRAR LAS RESPUESTAS CONFIGURADAS, ESTA CONDICION SE APLICA A LA
  --ULTIMA RESPUESTA SELECCIONADA
  
     GIC_N_CARACTERIZACION.SP_GET_RESPUESTANO(pPRE_IDPREGUNTA,pINS_IDINSTRUMENTO,pIDTEMA,pHOG_CODIGO, pRESPUESTASN);
    
      
     IF pRESPUESTASN IS NULL THEN
        pCONSULTA := ' SELECT RI.INS_IDINSTRUMENTO, RI.RES_IDRESPUESTA, RE.RES_RESPUESTA, RI.PRE_VALIDADOR, RI.PRE_LONGCAMPO, RE.PRE_IDPREGUNTA,
              RI.PRE_VALIDADOR_MIN, RI.PRE_VALIDADOR_MAX, RI.RES_ORDENRESPUESTA, RI.PRE_CAMPOTEX, RI.RES_OBLIGATORIO, RI.RES_HABILITA, RI.RES_FINALIZA, RI.RES_AUTOCOMPLETAR
              FROM GIC_N_INSTRUMENTOXRESP RI
              JOIN GIC_N_RESPUESTAS RE ON RE.RES_IDRESPUESTA=RI.RES_IDRESPUESTA AND RE.RES_ACTIVA=''SI''
              JOIN GIC_N_INSTRUMENTOXPREG PRE ON PRE.PRE_IDPREGUNTA=RE.PRE_IDPREGUNTA
              WHERE RE.PRE_IDPREGUNTA='||pPRE_IDPREGUNTA;
              OPEN cur_OUT FOR pCONSULTA;   
       
     ELSE 
      pCONSULTA := ' SELECT RI.INS_IDINSTRUMENTO, RI.RES_IDRESPUESTA, RE.RES_RESPUESTA, RI.PRE_VALIDADOR, RI.PRE_LONGCAMPO, RE.PRE_IDPREGUNTA,
              RI.PRE_VALIDADOR_MIN, RI.PRE_VALIDADOR_MAX, RI.RES_ORDENRESPUESTA, RI.PRE_CAMPOTEX, RI.RES_OBLIGATORIO, RI.RES_HABILITA, RI.RES_FINALIZA, RI.RES_AUTOCOMPLETAR
              FROM GIC_N_INSTRUMENTOXRESP RI
              JOIN GIC_N_RESPUESTAS RE ON RE.RES_IDRESPUESTA=RI.RES_IDRESPUESTA AND RE.RES_ACTIVA=''SI''
              JOIN GIC_N_INSTRUMENTOXPREG PRE ON PRE.PRE_IDPREGUNTA=RE.PRE_IDPREGUNTA
              WHERE RE.PRE_IDPREGUNTA='||pPRE_IDPREGUNTA||'   AND RE.RES_IDRESPUESTA NOT IN'|| pRESPUESTASN || '';      
              OPEN cur_OUT FOR pCONSULTA;
      END IF;  
    
         
    --ESTA OPCION INDICA QUE SE DEBEN MOSTRAR LAS RESPUESTAS CONFIGURADAS EN LA COLUMNA RES_RESPUESTAHABILITAR
    --DE LA TABLA GIC_N_INSTRUMENTOXRESP, DADO EL IDRESPUESTA EN LA COLUMNA VAL_RESPUESTAMULTIPLE DE LA TABLA
    --GIC_N_INSTRUMENTOXPREG
  ELSIF pMULTIPLE > 2  THEN    
    
        SELECT R.VAL_RESPUESTAMULTIPLE  INTO pDATOVALIDADOR
               FROM  GIC_N_INSTRUMENTOXPREG R 
               WHERE R.PRE_IDPREGUNTA=pPRE_IDPREGUNTA 
               AND R.VAL_RESPUESTAMULTIPLE IS NOT NULL;          
   
     SELECT COUNT(1) INTO pCANTIDAD 
       FROM GIC_N_RESPUESTASENCUESTA R 
      WHERE R.RES_IDRESPUESTA = pDATOVALIDADOR
        AND R.HOG_CODIGO = pHOG_CODIGO;
     
     IF pCANTIDAD > 0 THEN
       
       SELECT T.RES_RESPUESTASHABILITAR INTO pRESPUESTAS
        FROM GIC_N_INSTRUMENTOXRESP T   WHERE T.RES_IDRESPUESTA IN pDATOVALIDADOR;
       pCONSULTA := ' SELECT RI.INS_IDINSTRUMENTO, RI.RES_IDRESPUESTA, RE.RES_RESPUESTA, RI.PRE_VALIDADOR, RI.PRE_LONGCAMPO, RE.PRE_IDPREGUNTA,
          RI.PRE_VALIDADOR_MIN, RI.PRE_VALIDADOR_MAX, RI.RES_ORDENRESPUESTA, RI.PRE_CAMPOTEX, RI.RES_OBLIGATORIO, RI.RES_HABILITA, RI.RES_FINALIZA, RI.RES_AUTOCOMPLETAR
          FROM GIC_N_INSTRUMENTOXRESP RI
          JOIN GIC_N_RESPUESTAS RE ON RE.RES_IDRESPUESTA=RI.RES_IDRESPUESTA AND RE.RES_ACTIVA=''SI''
          JOIN GIC_N_INSTRUMENTOXPREG PRE ON PRE.PRE_IDPREGUNTA=RE.PRE_IDPREGUNTA
          WHERE RE.PRE_IDPREGUNTA='||pPRE_IDPREGUNTA||' AND RE.RES_IDRESPUESTA IN '|| pRESPUESTAS || '';      
          OPEN cur_OUT FOR pCONSULTA;
       
     ELSE
       pCONSULTA := ' SELECT RI.INS_IDINSTRUMENTO, RI.RES_IDRESPUESTA, RE.RES_RESPUESTA, RI.PRE_VALIDADOR, RI.PRE_LONGCAMPO, RE.PRE_IDPREGUNTA,
          RI.PRE_VALIDADOR_MIN, RI.PRE_VALIDADOR_MAX, RI.RES_ORDENRESPUESTA, RI.PRE_CAMPOTEX, RI.RES_OBLIGATORIO, RI.RES_HABILITA, RI.RES_FINALIZA, RI.RES_AUTOCOMPLETAR
          FROM GIC_N_INSTRUMENTOXRESP RI
          JOIN GIC_N_RESPUESTAS RE ON RE.RES_IDRESPUESTA=RI.RES_IDRESPUESTA AND RE.RES_ACTIVA=''SI''
          JOIN GIC_N_INSTRUMENTOXPREG PRE ON PRE.PRE_IDPREGUNTA=RE.PRE_IDPREGUNTA
          WHERE RE.PRE_IDPREGUNTA='||pPRE_IDPREGUNTA;      
          OPEN cur_OUT FOR pCONSULTA;
     END IF;

  END IF;

Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_GET_RESPUESTASXPREMOD',pHOG_CODIGO);
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_GET_RESPUESTASXPREMOD',pHOG_CODIGO);

END  SP_GET_RESPUESTASXPREMOD;
   
--TRAE LAS RESPUESTAS A LA PREGUNTA Y VALIDA QUE EL NUMERO DE MIEMBROS DEL HOGAR 
--CUMPLA CON EL CONTEO DE LOS VALIDADORES POR PERSONA CON ESTA
PROCEDURE SP_GET_RESPUESTASVALXCONTEO  (
     pPRE_IDPREGUNTA IN NUMBER,
     pINS_IDINSTRUMENTO IN NUMBER,
     pHOG_CODIGO IN VARCHAR,
     pPER_IDPERSONA IN NUMBER,
     cur_OUT OUT GIC_CURSOR.cursor_select
  ) AS
  
  pRE_IDVALIDADOR NUMBER;
  pCONTEOVAL NUMBER;
  pCONTEOHOGAR NUMBER;
  pFILTRO VARCHAR2(100);
  pDIFERENCIADO VARCHAR2(100);  
  pCONTEOFILTRO NUMBER;
  pCONSULTA VARCHAR2(2000); 
  pCANTIDAD NUMBER;
  pSALIDA VARCHAR(200);
  pX NUMBER;
  pDATOVALIDADOR VARCHAR(200);
  pVAL_IDVALIDADOR NUMBER;
  VP NUMBER;
  VD NUMBER;
  pDEFAULT VARCHAR2(500);

BEGIN
    VP := 2;
  
  SELECT COUNT(1) INTO pRE_IDVALIDADOR 
    FROM GIC_N_INSTRUMENTOXPREG R 
   WHERE R.PRE_IDPREGUNTA=pPRE_IDPREGUNTA 
     AND R.VAL_PREGUNTA_GENERAL IS NOT NULL;

      IF pRE_IDVALIDADOR > 0 THEN        
          
        --asigna validador para realizar conteo y compara con numeros de miembros total del hogar
        SELECT R.VAL_PREGUNTA_GENERAL INTO pDATOVALIDADOR 
               FROM  GIC_N_INSTRUMENTOXPREG R 
               WHERE R.PRE_IDPREGUNTA=pPRE_IDPREGUNTA 
               AND R.VAL_PREGUNTA_GENERAL IS NOT NULL;
        
        --INICIO PRUEBA ANDRES
                        
        SELECT length(VAL_PREGUNTA_GENERAL) - length(REPLACE(VAL_PREGUNTA_GENERAL,','))
        INTO   pCANTIDAD  FROM GIC_N_INSTRUMENTOXPREG WHERE PRE_IDPREGUNTA =pPRE_IDPREGUNTA;
                
        FOR VARIABLECONTADOR IN 1..pCANTIDAD LOOP
        pSALIDA:=GETTOKEN(pDATOVALIDADOR,VARIABLECONTADOR,',');
        SELECT P.EXPRESION INTO pX FROM GIC_N_VALIDADORXEXPRESION  P WHERE P.VALOR=pSALIDA
        AND P.PRE_IDPREGUNTA=pPRE_IDPREGUNTA;
        --CONTEO VALIDADOR ENCONTRADO
         SELECT COUNT(T.VAL_IDVALIDADOR) INTO pVAL_IDVALIDADOR FROM GIC_N_VALIDADORESXPERSONA T 
         WHERE T.HOG_CODIGO = pHOG_CODIGO AND T.VAL_IDVALIDADOR=pSALIDA;
        
        --CONTEO DE EL NUMERODE  MIENBROS DEL HOGAR
         SELECT COUNT(1) INTO pCONTEOHOGAR 
           FROM GIC_MIEMBROS_HOGAR MH 
          WHERE MH.HOG_CODIGO=pHOG_CODIGO;
        --CONDICION PARA VERIFICAR EL VALOR DE LA TABLA ENCONTRADA
        -- 0 VERIFICA QUE EL VALIDADOR SE CUMPLA PARA TODOS LOS MIEMBORS DEL HOGAR
        IF pX = 0 THEN        
           IF pVAL_IDVALIDADOR = pCONTEOHOGAR  THEN
            SELECT regexp_substr(G.VAL_DIFERENCIADONU,'\((\d+,)+(\d+\))',instr(G.VAL_DIFERENCIADONU,pSALIDA)+LENGTH(pSALIDA))
             INTO pDIFERENCIADO FROM GIC_N_INSTRUMENTOXPREG g WHERE PRE_IDPREGUNTA = pPRE_IDPREGUNTA;
             VP := 1;
             EXIT;
           END IF;   
        -- 1 VERIFICA QUE EL VALIDADROSE CUMPLA PARA UN SOLO MIEMBORS DEL HOGAR
        ELSIF pX = 1 THEN
          IF pVAL_IDVALIDADOR > 0 THEN
             SELECT regexp_substr(G.VAL_DIFERENCIADONU,'\((\d+,)+(\d+\))',instr(G.VAL_DIFERENCIADONU,pSALIDA)+LENGTH(pSALIDA))
             INTO pDIFERENCIADO FROM GIC_N_INSTRUMENTOXPREG g WHERE PRE_IDPREGUNTA = pPRE_IDPREGUNTA;
             VP :=1; 
             EXIT;
          END IF;

        ELSE
         IF pVAL_IDVALIDADOR > 0 THEN
          SELECT regexp_substr(G.VAL_DIFERENCIADONU,'\((\d+,)+(\d+\))',instr(G.VAL_DIFERENCIADONU,pSALIDA)+LENGTH(pSALIDA))
          INTO pDIFERENCIADO FROM GIC_N_INSTRUMENTOXPREG g WHERE PRE_IDPREGUNTA = pPRE_IDPREGUNTA;  
         EXIT;
         END IF;
        END IF;   
     
        END LOOP;       
        
        
        SELECT COUNT(T.R_DEFAULT) INTO VD  FROM GIC_N_INSTRUMENTOXPREG T WHERE t.pre_idpregunta in (pPRE_IDPREGUNTA);
        IF VD > 0 THEN
        SELECT T.R_DEFAULT INTO pDEFAULT   FROM GIC_N_INSTRUMENTOXPREG T WHERE t.pre_idpregunta in (pPRE_IDPREGUNTA);
        ELSE
          pDEFAULT := NULL;
        END IF;
        
        IF pDIFERENCIADO IS NOT NULL AND pVAL_IDVALIDADOR > 0 THEN
           pCONSULTA := ' SELECT RI.INS_IDINSTRUMENTO, RI.RES_IDRESPUESTA, RE.RES_RESPUESTA, RI.PRE_VALIDADOR, RI.PRE_LONGCAMPO, RE.PRE_IDPREGUNTA,
                RI.PRE_VALIDADOR_MIN, RI.PRE_VALIDADOR_MAX, RI.RES_ORDENRESPUESTA, RI.PRE_CAMPOTEX, RI.RES_OBLIGATORIO, RI.RES_HABILITA, RI.RES_FINALIZA, RI.RES_AUTOCOMPLETAR
                FROM GIC_N_INSTRUMENTOXRESP RI
                JOIN GIC_N_RESPUESTAS RE ON RE.RES_IDRESPUESTA=RI.RES_IDRESPUESTA AND RE.RES_ACTIVA=''SI''
                JOIN GIC_N_INSTRUMENTOXPREG PRE ON PRE.PRE_IDPREGUNTA=RE.PRE_IDPREGUNTA
                WHERE RE.PRE_IDPREGUNTA='||pPRE_IDPREGUNTA||' AND RE.RES_IDRESPUESTA IN '|| pDIFERENCIADO || '';      
                OPEN cur_OUT FOR pCONSULTA;
        ELSIF VP = 2 AND  VD > 0 THEN
                pCONSULTA := ' SELECT RI.INS_IDINSTRUMENTO, RI.RES_IDRESPUESTA, RE.RES_RESPUESTA, RI.PRE_VALIDADOR, RI.PRE_LONGCAMPO, RE.PRE_IDPREGUNTA,
                RI.PRE_VALIDADOR_MIN, RI.PRE_VALIDADOR_MAX, RI.RES_ORDENRESPUESTA, RI.PRE_CAMPOTEX, RI.RES_OBLIGATORIO, RI.RES_HABILITA, RI.RES_FINALIZA, RI.RES_AUTOCOMPLETAR
                FROM GIC_N_INSTRUMENTOXRESP RI
                JOIN GIC_N_RESPUESTAS RE ON RE.RES_IDRESPUESTA=RI.RES_IDRESPUESTA AND RE.RES_ACTIVA=''SI''
                JOIN GIC_N_INSTRUMENTOXPREG PRE ON PRE.PRE_IDPREGUNTA=RE.PRE_IDPREGUNTA
                WHERE RE.PRE_IDPREGUNTA='||pPRE_IDPREGUNTA||' AND RE.RES_IDRESPUESTA IN  '|| pDEFAULT || '';      
                OPEN cur_OUT FOR pCONSULTA;
        ELSE 
           OPEN cur_OUT FOR
                SELECT RI.INS_IDINSTRUMENTO, RI.RES_IDRESPUESTA, RE.RES_RESPUESTA, RI.PRE_VALIDADOR, RI.PRE_LONGCAMPO, RE.PRE_IDPREGUNTA,
                RI.PRE_VALIDADOR_MIN, RI.PRE_VALIDADOR_MAX, RI.RES_ORDENRESPUESTA, RI.PRE_CAMPOTEX, RI.RES_OBLIGATORIO, RI.RES_HABILITA, RI.RES_FINALIZA, RI.RES_AUTOCOMPLETAR
                FROM GIC_N_INSTRUMENTOXRESP RI
                JOIN GIC_N_RESPUESTAS RE ON RE.RES_IDRESPUESTA=RI.RES_IDRESPUESTA AND RE.RES_ACTIVA='SI'
                JOIN GIC_N_INSTRUMENTOXPREG PRE ON PRE.PRE_IDPREGUNTA=RE.PRE_IDPREGUNTA
                WHERE RE.PRE_IDPREGUNTA=pPRE_IDPREGUNTA AND GIC_N_CARACTERIZACION.FN_COMPROBARVALIDACIONESRESP(pPER_IDPERSONA,RE.RES_IDRESPUESTA,pHOG_CODIGO,pINS_IDINSTRUMENTO)=1; 
        END IF;     
      END IF;
      
  Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_GET_RESPUESTASVALXCONTEO','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_GET_RESPUESTASVALXCONTEO','');

  END SP_GET_RESPUESTASVALXCONTEO;
  
  PROCEDURE SP_GET_RESPUESTANO
   (
     pPRE_IDPREGUNTA IN NUMBER,
     pINS_IDINSTRUMENTO IN NUMBER,
     pIDTEMA IN NUMBER,
     pHOG_CODIGO IN VARCHAR,     
     pRESPUESTASN OUT VARCHAR2    
  )
  AS
  
 
  pOPCIONESMUL VARCHAR2(200);
  
  
   
  CURSOR C_RESPUESTAS IS
  SELECT  RE.RES_IDRESPUESTA 
  FROM GIC_N_RESPUESTASENCUESTA RE
  JOIN GIC_N_RESPUESTAS R ON R.RES_IDRESPUESTA = RE.RES_IDRESPUESTA
  JOIN GIC_N_INSTRUMENTOXPREG PR ON PR.PRE_IDPREGUNTA = R.PRE_IDPREGUNTA
  WHERE RE.usu_fechacreacion=(select max(usu_fechacreacion) 
  FROM GIC_N_RESPUESTASENCUESTA WHERE  HOG_CODIGO=pHOG_CODIGO)   
  AND  PR.TEM_IDTEMA =pIDTEMA AND RE.HOG_CODIGO=pHOG_CODIGO;  
  
  BEGIN
   
  FOR R_RESPUESTAS IN C_RESPUESTAS LOOP
  SELECT T.RES_RESPUESTASHABILITAR INTO pOPCIONESMUL  FROM GIC_N_INSTRUMENTOXRESP T 
  WHERE T.RES_IDRESPUESTA=R_RESPUESTAS.RES_IDRESPUESTA;
  
  IF pOPCIONESMUL IS NULL THEN
    pRESPUESTASN:=pRESPUESTASN;
  ELSIF pOPCIONESMUL IS NOT NULL THEN
    pRESPUESTASN:=pRESPUESTASN||','||pOPCIONESMUL;
  END IF;
  END LOOP;
   
  IF pRESPUESTASN IS NULL THEN
  NULL;
  ELSE 
   pRESPUESTASN:= replace(pRESPUESTASN,pRESPUESTASN,'('||substr( pRESPUESTASN, 2,length(pRESPUESTASN)-1));
   pRESPUESTASN:= pRESPUESTASN || ')';
  END IF;
  
  Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_GET_RESPUESTANO','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_GET_RESPUESTANO','');
  
  END  SP_GET_RESPUESTANO;
  
  
FUNCTION GetToken(stringvalues  VARCHAR2,
                  indice        NUMBER,
                  delim         VARCHAR2
                 )
RETURN VARCHAR2

IS

   start_pos NUMBER; -- Posicion inicial de cada substring
   end_pos   NUMBER; -- Posicion final de cada substring

BEGIN

   -- Si el primer indice es uno
   IF indice = 1 THEN

         start_pos := 1; -- La posicion inicial sera 1

   ELSE

         /* Se calcula la posicion del delimitador segun el substring que se desea conseguir  */
         /*             Ejm: 12;13;  Se desea el inidice 2 del delim ; --> start_pos=3        */

         start_pos := instr(stringvalues, delim, 1, indice - 1);

         -- Si la posicion inicial es 0 se retorna null
         IF start_pos = 0 THEN

             RETURN NULL;

         ELSE

             -- Se calcula la posicion inicial del substring sin importar el largo del delimitador
             start_pos := start_pos + length(delim);

         END IF;

   END IF;

   -- Se calcula la posicion final del substring
   end_pos := instr(stringvalues, delim, start_pos, 1);

   IF end_pos = 0 THEN -- Se retorna el ultimo valor del arreglo

         RETURN substr(stringvalues, start_pos);

   ELSE -- Se retorna el valor del arreglo segun el inidice y delim indicado

         RETURN substr(stringvalues, start_pos, end_pos - start_pos);

   END IF;
   
      Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'GetToken','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'GetToken','');

END GetToken;

PROCEDURE SP_GET_PREGUNTAS
   (
     pINS_IDINSTRUMENTO IN NUMBER,
     pHOG_CODIGO IN VARCHAR,
     pId_Tema IN NVARCHAR2,
     pPER_IDPERSONA IN NUMBER,
     pId_RespuestaEncuesta NVARCHAR2,
     pId_PreguntaPadre IN NUMBER,     
     pTipo_valres IN NUMBER  
  )
  AS  
    
  pPREGUNTA NVARCHAR2(50);
  pTodoHogar NVARCHAR2(50);
  pValidador NUMBER;
  pConteoHogar NUMBER;
  pConteo NUMBER;
  pTipo_valfun number;  
  p_final NUMBER;
  SALIDA NVARCHAR2(2);
  
 
 --CURSOR PARA OBTENER TODAS LAS PREGUNTAS CONFIGURADAS POR RESPUESTA
  CURSOR c_pPREGUNTAS IS  
  SELECT t.PRE_IDPREGUNTA  FROM GIC_N_PREGUNTAHIJOS t
  WHERE T.RES_IDRESPUESTA IN (pId_RespuestaEncuesta) AND T.PRE_DEPENDE='SI' ORDER BY PRE_DEPENDE DESC;
    
  
  BEGIN
  --MARCADOR PARA VERIFICAR SALIDA DEL CURSOR CUANDO CUMPLA ALGUNA CONDICION
   p_final := 0;  
   
      --FOR PARA RECORRER EL CURSOR c_pPREGUNTAS
      FOR r_pPREGUNTAS IN c_pPREGUNTAS LOOP
    
            --TRAE TODAS LAS PREGUNTAS QUE DEBEN CUMPLIR VALIDACIONES
            SELECT t.pre_idpregunta, t.val_todohogar INTO pPREGUNTA, pTodoHogar from GIC_N_PREGUNTAHIJOS t
            WHERE res_idrespuesta IN (pId_RespuestaEncuesta) AND T.PRE_DEPENDE='SI'  
            AND T.PRE_IDPREGUNTA =r_pPREGUNTAS.Pre_Idpregunta  order by PRE_DEPENDE desc;

      IF p_final = 0 THEN
           FOR CUR_DATOS IN (select DISTINCT T.PER_IDPERSONA from GIC_MIEMBROS_HOGAR t WHERE hog_codigo=pHOG_CODIGO)
        LOOP
              --FUNCION QUE VALIDA QUE LA PREGUNTA CUMPLA CON LA REGLA CUNFIGURADA DE LA TABLA VALIDADORESXRESPUESTA
              pValidador := gic_n_caracterizacion.FN_VALIDARXRESPUESTA(pHOG_CODIGO,r_pPREGUNTAS.Pre_Idpregunta,0,CUR_DATOS.PER_IDPERSONA,pINS_IDINSTRUMENTO);
      --SI pTodoHogar ES MAYOR A 1 ENTONCES TODOS LOS MIEMBROS DEL HOGAR DEBEN RESPONDER LA MISMA RESPUESTA
           IF pTodoHogar > 1 THEN
           --CONTEO DE MIEMBROS DE HOGAR
            SELECT COUNT(1) INTO pConteoHogar 
              FROM GIC_MIEMBROS_HOGAR  MH 
             WHERE MH.HOG_CODIGO=pHOG_CODIGO;
            
           --CONTEO DE RESPUESTAS CONTESTADAS, PASANDOSE COMO PARAMETRO LA RESPUESTA CONFIGURADA, DONDE pTodoHogar
           --ES LA RESPUESTA QUE VA A VALIDAR
           SELECT COUNT (1) INTO pConteo
             FROM GIC_N_RESPUESTASENCUESTA PD 
            WHERE PD.HOG_CODIGO =pHOG_CODIGO 
              AND PD.RES_IDRESPUESTA =pTodoHogar
              AND PD.INS_IDINSTRUMENTO = pINS_IDINSTRUMENTO;

           --SI EL VALIDADOR ES 1 Y EL CONTEO DEL HOGAR ES IGUAL AL CONTEO DE RESPUESTA CONTESTADAS, TERMINA EL LOOP
            IF pValidador = 1 AND (pConteoHogar= pConteo )  THEN

              pTipo_valfun := 1;
               p_final := r_pPREGUNTAS.Pre_Idpregunta;
              EXIT;              
            ELSE
              pTipo_valfun := 0;
            END IF;
      --SI pTodoHogar ES IGUAL A 1, ALMENOS UNA PERSONAS DEL HOGAR, DEBE CUMPLIR LA CONDICIOON
      ELSIF pTodoHogar = 1 THEN
                    IF pValidador = 1 THEN
                     pTipo_valfun := 1;  
                    p_final := r_pPREGUNTAS.Pre_Idpregunta;
                    EXIT;
                  ELSE
                    pTipo_valfun := 0;
                  END IF;
      END IF;
      END LOOP;
      ELSE
        EXIT;
      END IF;
    
     END LOOP;
      IF pTipo_valfun = 1 THEN
           --Borrar las preguntas derivadas de la pregunta padre
           DELETE FROM GIC_N_PREGUNTASDERIVADAS
           WHERE hog_codigo=pHOG_CODIGO
           AND pre_idpreguntapadre=pId_PreguntaPadre
           AND per_idpersona=pPER_IDPERSONA
           AND ins_idinstrumento=pINS_IDINSTRUMENTO;
           COMMIT;
           --Insertar en preguntas derivadas la pregunta
           INSERT INTO GIC_N_PREGUNTASDERIVADAS (hog_codigo,PRE_IDPREGUNTA,
           PER_IDPERSONA,GUARDADO,INS_IDINSTRUMENTO,TEM_IDTEMA,PRE_IDPREGUNTAPADRE)
           values(pHOG_CODIGO,p_final,pPER_IDPERSONA,0,pINS_IDINSTRUMENTO,pId_Tema,pId_PreguntaPadre);
           p_final := 1;
            COMMIT;    
        ELSE
           --Borrar las preguntas derivadas QUE NO CUMPLE CONDICION
         FOR t_pPREGUNTAS IN c_pPREGUNTAS LOOP   
           DELETE FROM GIC_N_PREGUNTASDERIVADAS
           WHERE hog_codigo=pHOG_CODIGO
           AND pre_idpregunta=t_pPREGUNTAS.Pre_Idpregunta
           AND pre_idpreguntapadre=pId_PreguntaPadre
           AND per_idpersona=pPER_IDPERSONA
           AND ins_idinstrumento=pINS_IDINSTRUMENTO;
           COMMIT;
           END LOOP;  
           END IF;       
      
 
  COMMIT;  
   
  
  Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_GET_PREGUNTAS','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_GET_PREGUNTAS','');
  
  
  END  SP_GET_PREGUNTAS;
  
--16/02/2020  
PROCEDURE GIC_SP_OBDEPTOPORDT
(
  pHogar_Codigo NVARCHAR2,
  Id_dt In Number,
  cur_OUT OUT accionsocial.cursor_select
)
AS

Hogar_Codigo NVARCHAR2(50):=pHogar_Codigo;
pId_depto number:=Id_dt;
THogar_Codigo number := 0;
BEGIN
 
	select count(p.hogarcodigo) INTO THogar_Codigo
  from GIC_N_RELACION_DT_PUNTO p where p.hogarcodigo = Hogar_Codigo ;
  
  IF THogar_Codigo = 0 THEN

  INSERT INTO GIC_N_RELACION_DT_PUNTO VALUES
  (Hogar_Codigo,'1',Id_dt,'','','');
  COMMIT;
  
  END IF;
  
  IF THogar_Codigo > 0 THEN
  
  UPDATE GIC_N_RELACION_DT_PUNTO SET  IDDT = Id_dt
  WHERE hogarcodigo = Hogar_Codigo ;
  COMMIT;
  
  END IF;
  
  OPEN cur_OUT FOR
  SELECT DISTINCT T.Iddepartamento Id, T.DEPARTAMENTO Descripcion
  FROM  GIC_N_DT_PUNTOS_ATENCION T WHERE T.IDDT=Id_dt  ORDER BY 1;


END GIC_SP_OBDEPTOPORDT;

PROCEDURE GIC_SP_OBTDT
(
  Id_depto In Number,
  cur_OUT OUT accionsocial.cursor_select
)
AS

pId_depto number:=Id_depto;
BEGIN

  OPEN cur_OUT FOR

  SELECT DISTINCT T.IDDT Id, T.DT Descripcion
  FROM GIC_N_DT_PUNTOS_ATENCION  T  ORDER BY 2;

END GIC_SP_OBTDT;
--16/02/2020
PROCEDURE GIC_SP_OBTPUNTOATECION
(
  pHogar_Codigo NVARCHAR2,
  Id_DT In Number,
  cur_OUT OUT accionsocial.cursor_select
)
AS

Hogar_Codigo NVARCHAR2(50):=pHogar_Codigo;
pId_DT number:=Id_DT;
TOTALIDT NUMBER :=0;
TOTALIDP NUMBER :=0;

BEGIN
  
  UPDATE GIC_N_RELACION_DT_PUNTO SET  iddeptoaten = Id_dt
  WHERE hogarcodigo = Hogar_Codigo ;
  COMMIT;
  
  SELECT COUNT(PA.IDDT) INTO TOTALIDT FROM GIC_N_RELACION_DT_PUNTO PA
  WHERE hogarcodigo = Hogar_Codigo ;

  SELECT COUNT(PA.IDDT) INTO TOTALIDP FROM GIC_N_RELACION_DT_PUNTO PA
  WHERE hogarcodigo = Hogar_Codigo ;
  
  
  IF TOTALIDT > 0 AND TOTALIDP > 0 THEN
        SELECT PA.IDDT INTO TOTALIDT FROM GIC_N_RELACION_DT_PUNTO PA
        WHERE hogarcodigo = Hogar_Codigo ;

        SELECT PA.IDPUNTOATEN INTO TOTALIDP FROM GIC_N_RELACION_DT_PUNTO PA
        WHERE hogarcodigo = Hogar_Codigo ;
        
       OPEN cur_OUT FOR
      
        SELECT DISTINCT T.IDPUNTOATENCION Id,  T.PUNTO_ATENCION Descripcion
        FROM GIC_N_DT_PUNTOS_ATENCION T WHERE T.IDDT = TOTALIDT
        AND T.IDDEPARTAMENTO = pId_DT   ORDER BY 1;  
      
  ELSE
    
      OPEN cur_OUT FOR

      SELECT 0 Id, 'SELECCIONE' Descripcion
      FROM DUAL T; 
    
  END IF;
  



END GIC_SP_OBTPUNTOATECION;


PROCEDURE GIC_SP_OBMUNICIPIOATECION
(
  pHogar_Codigo NVARCHAR2,
  Id_PT In Number,
  cur_OUT OUT accionsocial.cursor_select
)
AS

pId_PT number:=Id_PT;
Hogar_Codigo NVARCHAR2(50):=pHogar_Codigo;
IdMun NVARCHAR2(50);
TOTALIDT NUMBER :=0;
TOTALIDP NUMBER :=0;

BEGIN

  UPDATE GIC_N_RELACION_DT_PUNTO SET  idpuntoaten = Id_PT
  WHERE hogarcodigo = Hogar_Codigo ;
  COMMIT;
  
  
  SELECT COUNT(PA.IDDT) INTO TOTALIDT FROM GIC_N_RELACION_DT_PUNTO PA
  WHERE hogarcodigo = Hogar_Codigo ;

  SELECT COUNT(PA.IDDEPTOATEN) INTO TOTALIDP FROM GIC_N_RELACION_DT_PUNTO PA
  WHERE hogarcodigo = Hogar_Codigo ;
    
  IF TOTALIDT > 0 AND TOTALIDP > 0 THEN
    
    SELECT PA.IDDT INTO TOTALIDT FROM GIC_N_RELACION_DT_PUNTO PA
    WHERE hogarcodigo = Hogar_Codigo ;

    SELECT PA.IDDEPTOATEN INTO TOTALIDP FROM GIC_N_RELACION_DT_PUNTO PA
    WHERE hogarcodigo = Hogar_Codigo ;
      
    OPEN cur_OUT FOR
  
    SELECT DISTINCT  T.Idmunicipio Id, T.MUNICIPIO Descripcion
    FROM GIC_N_DT_PUNTOS_ATENCION T
    WHERE T.IDDT = TOTALIDT AND T.IDDEPARTAMENTO = TOTALIDP AND T.IDPUNTOATENCION = pId_PT  ORDER BY 2;
    
  ELSE
     OPEN cur_OUT FOR
          
      SELECT 0 Id, 'SELECCIONE' Descripcion
      FROM DUAL T; 
  
  END IF;


END GIC_SP_OBMUNICIPIOATECION;

PROCEDURE GIC_SP_GUARDAMUNATEN
(
  pHogar_Codigo NVARCHAR2,
  Id_MA In Number,
  cur_OUT OUT accionsocial.cursor_select
)
AS

pId_MA number:=Id_MA;
Hogar_Codigo NVARCHAR2(50):=pHogar_Codigo;
IdMun NVARCHAR2(50);
BEGIN

  UPDATE GIC_N_RELACION_DT_PUNTO SET  IDMUNATEN = pId_MA
  WHERE hogarcodigo = Hogar_Codigo ;
  COMMIT;  


  OPEN cur_OUT FOR  
  SELECT * FROM DUAL T;

END GIC_SP_GUARDAMUNATEN;

--08/01/2020
  PROCEDURE SP_INSERTA_SOPORTES
  (
  pHOG_CODIGO IN VARCHAR2,
  pGuid IN VARCHAR2,
  pARC_URL IN VARCHAR2,
  pUSU_CREACION IN VARCHAR2,
  pTipopersona  IN NVARCHAR2,
  pSalida out NVARCHAR2
  )
 AS
BEGIN
--pSalida := sys_guid();
pSalida := pGuid;

 COMMIT;
  INSERT INTO GIC_ARCHIVO_SOPORTES
  (ID_TEMPORAL,HOG_CODIGO, ARC_URL, USU_USUARIOCREACION, USU_FECHACREACION, TIPO_PERSONA)
  VALUES
  (pSalida,pHOG_CODIGO,pARC_URL,pUSU_CREACION, SYSDATE, pTipopersona);
  COMMIT;
  
  Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_INSERTA_SOPORTES','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_INSERTA_SOPORTES','');
  
END;


PROCEDURE SP_UPDATE_SOPORTES
  (
  pHOG_CODIGO IN VARCHAR2,
  psys_guid IN VARCHAR2,
  pSalida out NVARCHAR2
  )
 AS
BEGIN

  UPDATE GIC_ARCHIVO_SOPORTES  SET HOG_CODIGO  = pHOG_CODIGO WHERE ID_TEMPORAL = psys_guid;
  COMMIT;
  pSalida := 1;
  
  Exception  when others then
    SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_UPDATE_SOPORTES','');
    SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_UPDATE_SOPORTES','');
  
    
END SP_UPDATE_SOPORTES;

PROCEDURE CERRAR_ENCUESTA
  (
  pHOG_CODIGO IN VARCHAR2,
  RESULT out NVARCHAR2  
  )
 AS
BEGIN

  UPDATE GIC_HOGAR SET ESTADO = 'CERRADA' WHERE HOG_CODIGO = pHOG_CODIGO;
  COMMIT;
  RESULT := 1;
  
  Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'CERRAR_ENCUESTA','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'CERRAR_ENCUESTA','');
    
END;

FUNCTION FN_RETORNA_TIPO_PERSONA (pIdPersona IN INTEGER,  pHOG_CODIGO IN VARCHAR2) RETURN INTEGER
    IS
    total INTEGER;
    IdPersona  INTEGER;
  BEGIN
    
    SELECT COUNT(P.PER_IDPERSONA) INTO total FROM GIC_N_VALIDADORESXPERSONA P
    WHERE P.HOG_CODIGO = pHOG_CODIGO AND P.VAL_IDVALIDADOR IN (5001,5002,5003)
    AND P.PER_IDPERSONA = pIdPersona ;
    
    IF total > 0 THEN

    SELECT P.PER_IDPERSONA INTO IdPersona FROM GIC_N_VALIDADORESXPERSONA P
    WHERE P.HOG_CODIGO = pHOG_CODIGO AND P.VAL_IDVALIDADOR IN (5001,5002,5003)
    AND P.PER_IDPERSONA = pIdPersona ;

    ELSE
      IdPersona := 0;
    END IF;
    
    RETURN IdPersona;
    
    Exception  when others then
    SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'FN_RETORNA_TIPO_PERSONA','');
    SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'FN_RETORNA_TIPO_PERSONA','');
    
    
  END FN_RETORNA_TIPO_PERSONA;
  
  PROCEDURE SP_INS_ETNIA_ARES(CODHOGAR IN  NVARCHAR2)AS
        
    TOTAL_PERSONA_TUTOR NUMBER;
    TOTAL_DES_5001_5004 NUMBER;
    ID_PERSONA_TUTOR NUMBER;
    ID_PERSONA_T NUMBER;
    TOTAL_T  NUMBER;
    CODHOGAR_T  NVARCHAR2(100);
    TOTAL_IND   NUMBER;
    TOTAL_GIT   NUMBER;
    TOTAL_RAI   NUMBER;
    TOTAL_PAL   NUMBER;
    TOTAL_NEG   NUMBER;
    TOTAL_DES NUMBER;
    TOTAL_NIN NUMBER;
    TOTAL_267_266_173 NUMBER;
    VALOR_267_266_173 VARCHAR2(500);
    
    
    BEGIN
    TOTAL_PERSONA_TUTOR:=0;
    TOTAL_DES_5001_5004:=0;
    ID_PERSONA_TUTOR:=0;
    ID_PERSONA_T:=0; TOTAL_T :=0; CODHOGAR_T := CODHOGAR; 
    TOTAL_IND :=0;
    TOTAL_GIT :=0;
    TOTAL_RAI :=0;
    TOTAL_PAL :=0;
    TOTAL_NEG :=0;
    TOTAL_DES :=0;
    TOTAL_NIN :=0;
    TOTAL_267_266_173 := 0;
    VALOR_267_266_173 := '';
    
    /*
    163 INDIGENA
    164 GITANO
    165 RAIZAL
    166 PALENQUERO
    167 NEGRO
    105 DESPLAZAMIENTO FORZADO
    */
    
     
     DELETE FROM  gic_n_validadoresxpersona t WHERE T.HOG_CODIGO = CODHOGAR_T AND T.VAL_IDVALIDADOR IN (5007,5008,5009,5010,5011,5012,506)
     AND T.COMODIN = 1;
     COMMIT;   
     
     DELETE FROM  gic_n_validadoresxpersona t WHERE T.HOG_CODIGO = CODHOGAR_T AND T.VAL_IDVALIDADOR IN (267,266,173)
     AND T.COMODIN = 2;
     COMMIT;
     

          SELECT COUNT(GVP.PER_IDPERSONA) INTO TOTAL_T FROM GIC_N_VALIDADORESXPERSONA GVP WHERE GVP.VAL_IDVALIDADOR IN (5001,5002,5003) AND GVP.HOG_CODIGO = CODHOGAR_T;
          SELECT COUNT(GVP.PER_IDPERSONA) INTO TOTAL_PERSONA_TUTOR FROM GIC_N_VALIDADORESXPERSONA GVP WHERE GVP.VAL_IDVALIDADOR IN (5001) AND GVP.HOG_CODIGO = CODHOGAR_T;
          
          IF TOTAL_T > 0 THEN
                  SELECT MAX(GVP.PER_IDPERSONA) INTO ID_PERSONA_T FROM GIC_N_VALIDADORESXPERSONA GVP WHERE GVP.VAL_IDVALIDADOR IN (5001,5002,5003) AND GVP.HOG_CODIGO = CODHOGAR_T;
                  IF TOTAL_PERSONA_TUTOR > 0 THEN
                     SELECT MAX(GVP.PER_IDPERSONA) INTO ID_PERSONA_TUTOR FROM GIC_N_VALIDADORESXPERSONA GVP WHERE GVP.VAL_IDVALIDADOR IN (5001) AND GVP.HOG_CODIGO = CODHOGAR_T;
                  END IF;
                  SELECT COUNT(GVP.PER_IDPERSONA) INTO TOTAL_IND FROM GIC_N_VALIDADORESXPERSONA GVP WHERE GVP.VAL_IDVALIDADOR IN (163) AND GVP.HOG_CODIGO = CODHOGAR_T ;
                  SELECT COUNT(GVP.PER_IDPERSONA) INTO TOTAL_GIT FROM GIC_N_VALIDADORESXPERSONA GVP WHERE GVP.VAL_IDVALIDADOR IN (164) AND GVP.HOG_CODIGO = CODHOGAR_T ;
                  SELECT COUNT(GVP.PER_IDPERSONA) INTO TOTAL_RAI FROM GIC_N_VALIDADORESXPERSONA GVP WHERE GVP.VAL_IDVALIDADOR IN (165) AND GVP.HOG_CODIGO = CODHOGAR_T ;
                  SELECT COUNT(GVP.PER_IDPERSONA) INTO TOTAL_PAL FROM GIC_N_VALIDADORESXPERSONA GVP WHERE GVP.VAL_IDVALIDADOR IN (166) AND GVP.HOG_CODIGO = CODHOGAR_T ;
                  SELECT COUNT(GVP.PER_IDPERSONA) INTO TOTAL_NEG FROM GIC_N_VALIDADORESXPERSONA GVP WHERE GVP.VAL_IDVALIDADOR IN (167) AND GVP.HOG_CODIGO = CODHOGAR_T ;
                  SELECT COUNT(GVP.PER_IDPERSONA) INTO TOTAL_DES FROM GIC_N_VALIDADORESXPERSONA GVP WHERE GVP.VAL_IDVALIDADOR IN (105) AND GVP.HOG_CODIGO = CODHOGAR_T ;
                  SELECT COUNT(GVP.PER_IDPERSONA) INTO TOTAL_NIN FROM GIC_N_VALIDADORESXPERSONA GVP WHERE GVP.VAL_IDVALIDADOR IN (272) AND GVP.HOG_CODIGO = CODHOGAR_T ;
                  SELECT COUNT(GVP.PER_IDPERSONA) INTO TOTAL_267_266_173 FROM GIC_N_VALIDADORESXPERSONA GVP WHERE GVP.VAL_IDVALIDADOR IN (267,266,173)  AND GVP.HOG_CODIGO = CODHOGAR_T ;
                

                 IF TOTAL_267_266_173 > 0 THEN
                     SELECT GVP.VAL_IDVALIDADOR INTO TOTAL_267_266_173 FROM GIC_N_VALIDADORESXPERSONA GVP WHERE GVP.VAL_IDVALIDADOR IN (267,266,173)  AND GVP.HOG_CODIGO = CODHOGAR_T ;
                     SELECT GVP.PRE_VALOR INTO VALOR_267_266_173 FROM GIC_N_VALIDADORESXPERSONA GVP WHERE GVP.VAL_IDVALIDADOR IN (267,266,173) AND GVP.HOG_CODIGO = CODHOGAR_T ;
                     FOR CUR_DATOS IN (SELECT PER_IDPERSONA, VAL_IDVALIDADOR, HOG_CODIGO FROM (SELECT  T.PER_IDPERSONA, T.VAL_IDVALIDADOR, T.HOG_CODIGO FROM GIC_N_VALIDADORESXPERSONA T WHERE T.HOG_CODIGO = CODHOGAR_T AND T.VAL_IDVALIDADOR IN (5001,5002,5003,5004)) X WHERE X.VAL_IDVALIDADOR = 5004)
                        LOOP
                        IF CUR_DATOS.PER_IDPERSONA IS NOT NULL   THEN                       
                           INSERT INTO GIC_N_VALIDADORESXPERSONA VALUES (1,CUR_DATOS.PER_IDPERSONA,TOTAL_267_266_173, VALOR_267_266_173,CUR_DATOS.HOG_CODIGO,2,'');
                           COMMIT;
                       END IF;
                      END LOOP;
                                         
                 END IF;
                
                 
                 IF TOTAL_IND > 0 THEN
                        INSERT INTO GIC_N_VALIDADORESXPERSONA VALUES (1,ID_PERSONA_T,'5007',UPPER(TRIM('INDIGENA')),CODHOGAR_T,1,'');
                        COMMIT;                  
                 END IF;
                 IF TOTAL_GIT > 0 THEN
                        INSERT INTO GIC_N_VALIDADORESXPERSONA VALUES (1,ID_PERSONA_T,'5008',UPPER(TRIM('GITANO')),CODHOGAR_T,1,'');
                        COMMIT;                  
                 END IF;
                 IF TOTAL_RAI > 0 THEN
                        INSERT INTO GIC_N_VALIDADORESXPERSONA VALUES (1,ID_PERSONA_T,'5009',UPPER(TRIM('RAIZAL')),CODHOGAR_T,1,'');
                        COMMIT;                  
                 END IF;
                 IF TOTAL_PAL > 0 THEN
                        INSERT INTO GIC_N_VALIDADORESXPERSONA VALUES (1,ID_PERSONA_T,'5010',UPPER(TRIM('PALENQUERO')),CODHOGAR_T,1,'');
                        COMMIT;                  
                 END IF;
                 IF TOTAL_NEG > 0 THEN
                        INSERT INTO GIC_N_VALIDADORESXPERSONA VALUES (1,ID_PERSONA_T,'5011',UPPER(TRIM('NEGRO')),CODHOGAR_T,1,'');
                        COMMIT;                  
                END IF;
                IF TOTAL_DES > 0 THEN
                        SELECT COUNT(VP.PER_IDPERSONA) INTO TOTAL_DES_5001_5004 FROM GIC_N_VALIDADORESXPERSONA VP WHERE VP.PER_IDPERSONA IN 
                        (
                        SELECT GVP.PER_IDPERSONA
                        FROM GIC_N_VALIDADORESXPERSONA GVP WHERE GVP.VAL_IDVALIDADOR IN (105) 
                        AND GVP.HOG_CODIGO = CODHOGAR_T
                        ) AND VP.HOG_CODIGO = CODHOGAR_T AND VP.VAL_IDVALIDADOR IN (5001,5004);
                        
                        IF TOTAL_DES_5001_5004 > 0 THEN
                          SELECT GVP.PER_IDPERSONA INTO ID_PERSONA_TUTOR FROM GIC_N_VALIDADORESXPERSONA GVP WHERE GVP.VAL_IDVALIDADOR IN (5001,5002,5003) AND GVP.HOG_CODIGO = CODHOGAR_T;                      
                          INSERT INTO GIC_N_VALIDADORESXPERSONA VALUES (1,ID_PERSONA_TUTOR,'506',UPPER(TRIM('DESPLAZAMIENTO FORZADO')),CODHOGAR_T,1,'');
                          COMMIT;
                        END IF;
                END IF;
                IF TOTAL_NIN > 0 THEN
                        INSERT INTO GIC_N_VALIDADORESXPERSONA VALUES (1,ID_PERSONA_T,'5012',UPPER(TRIM('NINGUNADELASANTERIORES')),CODHOGAR_T,1,'');
                        COMMIT;                  
                END IF;                
                
          ELSE
              NULL;
          END IF;
          
          Exception  when others then
        SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_INS_ETNIA_ARES',CODHOGAR);
                SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_INS_ETNIA_ARES',CODHOGAR);
   
      END SP_INS_ETNIA_ARES;
      
PROCEDURE SP_CONSTANCIA(COD_HOGAR IN  NVARCHAR2, cur_OUT OUT gic_cursor.cursor_select )AS   
CODHOGAR_T  NVARCHAR2(100);
  
BEGIN
  CODHOGAR_T := COD_HOGAR;
  
  OPEN cur_OUT FOR
select x.HOG_CODIGO,
x.ID_TIPO_PERSONA,
x.TIPO_PERSONA,
x.PER_PRIMERNOMBRE,
x.PER_SEGUNDONOMBRE,
x.PER_PRIMERAPELLIDO,
x.PER_SEGUNDOAPELLIDO,
x.PER_TIPODOC,
x.PER_NUMERODOC,
x.ESTADO_ENCUESTA,
x.DEPTO_ATENCION,
x.MUN_ATENCION,
x.PUNTO_ATENCION,
x.FECHA_ATENCION,
x.DEPTO_RESIDENCIA,
x.MUN_RESIDENCIA,
x.ESTADO_RUV,
x.HECHO_VICTIMIZANTE_1,
x.HECHO_VICTIMIZANTE_2,
x.HECHO_VICTIMIZANTE_3,
x.HECHO_VICTIMIZANTE_4,
nvl(x.HECHO_VICTIMIZANTE_5,'SIN INFORMACION') HECHO_VICTIMIZANTE_5,
x.HECHO_VICTIMIZANTE_6,
x.HECHO_VICTIMIZANTE_7,
x.HECHO_VICTIMIZANTE_8,
x.HECHO_VICTIMIZANTE_9,
x.HECHO_VICTIMIZANTE_10,
x.HECHO_VICTIMIZANTE_11,
x.HECHO_VICTIMIZANTE_12,
x.HECHO_VICTIMIZANTE_13,
x.HECHO_VICTIMIZANTE_14,
NVL(x.NOVEDAD_RUV,'NINGUNA') NOVEDAD_RUV,
CASE WHEN X.ESTADO_RUV = 'INCLUIDO' THEN x.NECESIDAD_IDENTIFICADA ELSE '' END NECESIDAD_IDENTIFICADA,
CASE WHEN X.ESTADO_RUV = 'INCLUIDO' THEN x.MEDIDA_ASISTENCIA ELSE '' END MEDIDA_ASISTENCIA,
CASE WHEN X.ESTADO_RUV = 'INCLUIDO' THEN x.NECESIDAD_IDENTIFICADA_106 ELSE '' END NECESIDAD_IDENTIFICADA_106,
CASE WHEN X.ESTADO_RUV = 'INCLUIDO' THEN x.MEDIDA_ASISTENCIA_106 ELSE '' END MEDIDA_ASISTENCIA_106,
--CASE WHEN EDAD < 18 THEN x.NECESIDAD_IDENTIFICADA_248  ELSE '' END NECESIDAD_IDENTIFICADA_248,
CASE WHEN EDAD < 18 AND EDAD > 5 AND ESTADO_RUV = 'INCLUIDO' THEN x.NECESIDAD_IDENTIFICADA_248 WHEN EDAD >= 0 AND EDAD < 6 AND ESTADO_RUV = 'INCLUIDO' AND x.NECESIDAD_IDENTIFICADA_248 = 'Menor requiere acceso a educacion' THEN 'Menor requiere cuidado inicial'  ELSE '' END NECESIDAD_IDENTIFICADA_248,
CASE WHEN EDAD < 18 THEN x.MEDIDA_ASISTENCIA_248 ELSE '' END MEDIDA_ASISTENCIA_248,
x.NECESIDAD_IDENTIFICADA_3823 NT,
x.MEDIDA_ASISTENCIA_3823 MT,
CASE WHEN EDAD >= 18 THEN x.NECESIDAD_IDENTIFICADA_3823 ELSE '' END NECESIDAD_IDENTIFICADA_3823,
CASE WHEN EDAD >= 18 THEN x.MEDIDA_ASISTENCIA_3823 ELSE '' END MEDIDA_ASISTENCIA_3823,
x.NECESIDAD_IDENTIFICADA_276,
x.MEDIDA_ASISTENCIA_276,
x.NECESIDAD_IDENTIFICADA_3859,
x.MEDIDA_ASISTENCIA_3859,
CASE WHEN 1=2 THEN x.NECESIDAD_IDENTIFICADA_3832 ELSE '' END NECESIDAD_IDENTIFICADA_3832,
CASE WHEN 1=2 THEN x.MEDIDA_ASISTENCIA_3832 ELSE '' END MEDIDA_ASISTENCIA_3832,
CASE WHEN 1=2 THEN x.NECESIDAD_IDENTIFICADA_3833 ELSE '' END NECESIDAD_IDENTIFICADA_3833,
CASE WHEN 1=2 THEN x.MEDIDA_ASISTENCIA_3833 ELSE '' END MEDIDA_ASISTENCIA_3833,
CASE WHEN 1=2 THEN x.NECESIDAD_IDENTIFICADA_3834 ELSE '' END NECESIDAD_IDENTIFICADA_3834,
CASE WHEN 1=2 THEN x.MEDIDA_ASISTENCIA_3834 ELSE '' END MEDIDA_ASISTENCIA_3834,
CASE WHEN 1=2 THEN x.NECESIDAD_IDENTIFICADA_3835 ELSE '' END NECESIDAD_IDENTIFICADA_3835,
CASE WHEN 1=2 THEN x.MEDIDA_ASISTENCIA_3835 ELSE '' END MEDIDA_ASISTENCIA_3835,
CASE WHEN 1=2 THEN x.NECESIDAD_IDENTIFICADA_3836 ELSE '' END NECESIDAD_IDENTIFICADA_3836,
CASE WHEN 1=2 THEN x.MEDIDA_ASISTENCIA_3836 ELSE '' END MEDIDA_ASISTENCIA_3836,
CASE WHEN 1=2 THEN x.NECESIDAD_IDENTIFICADA_3837 ELSE '' END NECESIDAD_IDENTIFICADA_3837,
CASE WHEN 1=2 THEN x.MEDIDA_ASISTENCIA_3837 ELSE '' END MEDIDA_ASISTENCIA_3837,
CASE WHEN 1=2 THEN x.NECESIDAD_IDENTIFICADA_3838 ELSE '' END NECESIDAD_IDENTIFICADA_3838,
CASE WHEN 1=2 THEN x.MEDIDA_ASISTENCIA_3838 ELSE '' END MEDIDA_ASISTENCIA_3838,
CASE WHEN 1=2 THEN x.NECESIDAD_IDENTIFICADA_3839 ELSE '' END NECESIDAD_IDENTIFICADA_3839,
CASE WHEN 1=2 THEN x.MEDIDA_ASISTENCIA_3839 ELSE '' END  MEDIDA_ASISTENCIA_3839,
CASE WHEN 1=2 THEN x.NECESIDAD_IDENTIFICADA_3840 ELSE '' END NECESIDAD_IDENTIFICADA_3840,
CASE WHEN 1=2 THEN x.MEDIDA_ASISTENCIA_3840 ELSE '' END MEDIDA_ASISTENCIA_3840,
CASE WHEN 1=2 THEN x.NECESIDAD_IDENTIFICADA_3841 ELSE '' END NECESIDAD_IDENTIFICADA_3841,
CASE WHEN 1=2 THEN x.MEDIDA_ASISTENCIA_3841 ELSE '' END MEDIDA_ASISTENCIA_3841,
CASE WHEN 1=2 THEN x.NECESIDAD_IDENTIFICADA_3842 ELSE '' END NECESIDAD_IDENTIFICADA_3842,
CASE WHEN 1=2 THEN x.MEDIDA_ASISTENCIA_3842 ELSE '' END MEDIDA_ASISTENCIA_3842,
x.NECESIDAD_IDENTIFICADA_3864,
x.MEDIDA_ASISTENCIA_3864,
x.EDAD   from (  SELECT DISTINCT H.HOG_CODIGO, 
(SELECT IP.VAL_IDVALIDADOR FROM GIC_N_VALIDADORESXPERSONA IP WHERE IP.HOG_CODIGO=VP.HOG_CODIGO AND IP.PER_IDPERSONA=VP.PER_IDPERSONA AND IP.VAL_IDVALIDADOR IN (5001,5002,5003,5004)) ID_TIPO_PERSONA,
(SELECT IP.PRE_VALOR FROM GIC_N_VALIDADORESXPERSONA IP WHERE IP.HOG_CODIGO=VP.HOG_CODIGO AND IP.PER_IDPERSONA=VP.PER_IDPERSONA AND IP.VAL_IDVALIDADOR IN (5001,5002,5003,5004)) TIPO_PERSONA,
(SELECT REC.RXP_TEXTORESPUESTA FROM GIC_N_RESPUESTASENCUESTA_C REC WHERE REC.RES_IDRESPUESTA = '19' AND REC.HOG_CODIGO=C.HOG_CODIGO AND REC.PER_IDPERSONA=C.PER_IDPERSONA ) PER_PRIMERNOMBRE,
(SELECT REC.RXP_TEXTORESPUESTA FROM GIC_N_RESPUESTASENCUESTA_C REC WHERE REC.RES_IDRESPUESTA = '20' AND REC.HOG_CODIGO=C.HOG_CODIGO AND REC.PER_IDPERSONA=C.PER_IDPERSONA ) PER_SEGUNDONOMBRE,
(SELECT REC.RXP_TEXTORESPUESTA FROM GIC_N_RESPUESTASENCUESTA_C REC WHERE REC.RES_IDRESPUESTA = '21' AND REC.HOG_CODIGO=C.HOG_CODIGO AND REC.PER_IDPERSONA=C.PER_IDPERSONA ) PER_PRIMERAPELLIDO,
(SELECT REC.RXP_TEXTORESPUESTA FROM GIC_N_RESPUESTASENCUESTA_C REC WHERE REC.RES_IDRESPUESTA = '22' AND REC.HOG_CODIGO=C.HOG_CODIGO AND REC.PER_IDPERSONA=C.PER_IDPERSONA ) PER_SEGUNDOAPELLIDO,
(
SELECT
CASE
  WHEN REC.RES_IDRESPUESTA = '93' THEN 'CEDULA CIUDADANIA'
  WHEN  REC.RES_IDRESPUESTA = '3852' THEN 'CEDULA CIUDADANIA'
  WHEN  REC.RES_IDRESPUESTA = '3853' THEN 'CEDULA CIUDADANIA'
  WHEN  REC.RES_IDRESPUESTA = '3854' THEN 'CEDULA CIUDADANIA'
  WHEN  REC.RES_IDRESPUESTA = '94' THEN 'Cedula de Extranjeria'
  WHEN  REC.RES_IDRESPUESTA = '95' THEN 'Tarjeta de Identidad'
  WHEN  REC.RES_IDRESPUESTA = '96' THEN 'Registro Civil/NUIP'
  WHEN  REC.RES_IDRESPUESTA = '3799' THEN 'Permiso especial de permanencia'
  WHEN  REC.RES_IDRESPUESTA = '3800' THEN 'Permiso temporal de permanencia'
  WHEN  REC.RES_IDRESPUESTA = '3801' THEN 'Pasaporte'
  WHEN  REC.RES_IDRESPUESTA = '3802' THEN 'Adulto sin identificar'
  WHEN  REC.RES_IDRESPUESTA = '3803' THEN 'Menor sin identificar'
  WHEN  REC.RES_IDRESPUESTA = '3804' THEN 'Recien nacido'
  WHEN  REC.RES_IDRESPUESTA = '3805' THEN 'Certificado de pertenencia etnica'
  ELSE ''
  END PER_TIPODOC

FROM GIC_N_RESPUESTASENCUESTA_C REC WHERE REC.RES_IDRESPUESTA IN (93,3852,3853,3854,94,95,96,3799,3800,3801,3802,3803,3804,3805) AND REC.HOG_CODIGO=C.HOG_CODIGO AND REC.PER_IDPERSONA=C.PER_IDPERSONA ) PER_TIPODOC,
(SELECT REC.RXP_TEXTORESPUESTA FROM GIC_N_RESPUESTASENCUESTA_C REC WHERE REC.RES_IDRESPUESTA = '101' AND REC.HOG_CODIGO=C.HOG_CODIGO AND REC.PER_IDPERSONA=C.PER_IDPERSONA ) PER_NUMERODOC,

H.ESTADO ESTADO_ENCUESTA,

(SELECT PA.DEPARTAMENTO FROM GIC_N_RELACION_DT_PUNTO RL, GIC_N_DT_PUNTOS_ATENCION PA WHERE RL.IDDEPTOATEN=PA.IDDEPARTAMENTO AND RL.IDDT=PA.IDDT AND RL.IDPUNTOATEN=PA.IDPUNTOATENCION AND RL.IDMUNATEN=PA.IDMUNICIPIO AND RL.HOGARCODIGO=C.HOG_CODIGO ) DEPTO_ATENCION,
(SELECT PA.MUNICIPIO FROM GIC_N_RELACION_DT_PUNTO RL, GIC_N_DT_PUNTOS_ATENCION PA WHERE RL.IDDEPTOATEN=PA.IDDEPARTAMENTO AND RL.IDDT=PA.IDDT AND RL.IDPUNTOATEN=PA.IDPUNTOATENCION AND RL.IDMUNATEN=PA.IDMUNICIPIO AND RL.HOGARCODIGO=C.HOG_CODIGO ) MUN_ATENCION,
(SELECT PA.PUNTO_ATENCION FROM GIC_N_RELACION_DT_PUNTO RL, GIC_N_DT_PUNTOS_ATENCION PA WHERE RL.IDDEPTOATEN=PA.IDDEPARTAMENTO AND RL.IDDT=PA.IDDT AND RL.IDPUNTOATEN=PA.IDPUNTOATENCION AND RL.IDMUNATEN=PA.IDMUNICIPIO AND RL.HOGARCODIGO=C.HOG_CODIGO ) PUNTO_ATENCION,
H.USU_FECHACREACION FECHA_ATENCION,
(SELECT D.NOM_DEPTO FROM GIC_N_RESPUESTASENCUESTA_C RE JOIN GIC_MUNICIPIO M ON RE.RXP_TEXTORESPUESTA=M.ID_MUNI_DEPTO JOIN GIC_DEPARTAMENTO D ON D.ID_DEPTO=M.ID_DEPTO WHERE RE.RXP_TEXTORESPUESTA=M.ID_MUNI_DEPTO AND RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA = 6) DEPTO_RESIDENCIA,
(SELECT M.NOM_MUNICIPIO FROM GIC_N_RESPUESTASENCUESTA_C RE JOIN GIC_MUNICIPIO M ON RE.RXP_TEXTORESPUESTA=M.ID_MUNI_DEPTO WHERE RE.RXP_TEXTORESPUESTA=M.ID_MUNI_DEPTO AND RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA = 6) MUN_RESIDENCIA,
(SELECT IP.PRE_VALOR FROM GIC_N_VALIDADORESXPERSONA IP WHERE IP.HOG_CODIGO=VP.HOG_CODIGO AND IP.PER_IDPERSONA=VP.PER_IDPERSONA AND IP.VAL_IDVALIDADOR = 1) ESTADO_RUV,
(SELECT IP.PRE_VALOR FROM GIC_N_VALIDADORESXPERSONA IP WHERE IP.HOG_CODIGO=VP.HOG_CODIGO AND IP.PER_IDPERSONA=VP.PER_IDPERSONA AND IP.VAL_IDVALIDADOR = 101) HECHO_VICTIMIZANTE_1,
(SELECT IP.PRE_VALOR FROM GIC_N_VALIDADORESXPERSONA IP WHERE IP.HOG_CODIGO=VP.HOG_CODIGO AND IP.PER_IDPERSONA=VP.PER_IDPERSONA AND IP.VAL_IDVALIDADOR = 102) HECHO_VICTIMIZANTE_2,
(SELECT IP.PRE_VALOR FROM GIC_N_VALIDADORESXPERSONA IP WHERE IP.HOG_CODIGO=VP.HOG_CODIGO AND IP.PER_IDPERSONA=VP.PER_IDPERSONA AND IP.VAL_IDVALIDADOR = 103) HECHO_VICTIMIZANTE_3,
(SELECT IP.PRE_VALOR FROM GIC_N_VALIDADORESXPERSONA IP WHERE IP.HOG_CODIGO=VP.HOG_CODIGO AND IP.PER_IDPERSONA=VP.PER_IDPERSONA AND IP.VAL_IDVALIDADOR = 104) HECHO_VICTIMIZANTE_4,
(SELECT IP.PRE_VALOR FROM GIC_N_VALIDADORESXPERSONA IP WHERE IP.HOG_CODIGO=VP.HOG_CODIGO AND IP.PER_IDPERSONA=VP.PER_IDPERSONA AND IP.VAL_IDVALIDADOR = 105) HECHO_VICTIMIZANTE_5,
(SELECT IP.PRE_VALOR FROM GIC_N_VALIDADORESXPERSONA IP WHERE IP.HOG_CODIGO=VP.HOG_CODIGO AND IP.PER_IDPERSONA=VP.PER_IDPERSONA AND IP.VAL_IDVALIDADOR = 106) HECHO_VICTIMIZANTE_6,
(SELECT IP.PRE_VALOR FROM GIC_N_VALIDADORESXPERSONA IP WHERE IP.HOG_CODIGO=VP.HOG_CODIGO AND IP.PER_IDPERSONA=VP.PER_IDPERSONA AND IP.VAL_IDVALIDADOR = 107) HECHO_VICTIMIZANTE_7,
(SELECT IP.PRE_VALOR FROM GIC_N_VALIDADORESXPERSONA IP WHERE IP.HOG_CODIGO=VP.HOG_CODIGO AND IP.PER_IDPERSONA=VP.PER_IDPERSONA AND IP.VAL_IDVALIDADOR = 108) HECHO_VICTIMIZANTE_8,
(SELECT IP.PRE_VALOR FROM GIC_N_VALIDADORESXPERSONA IP WHERE IP.HOG_CODIGO=VP.HOG_CODIGO AND IP.PER_IDPERSONA=VP.PER_IDPERSONA AND IP.VAL_IDVALIDADOR = 109) HECHO_VICTIMIZANTE_9,
(SELECT IP.PRE_VALOR FROM GIC_N_VALIDADORESXPERSONA IP WHERE IP.HOG_CODIGO=VP.HOG_CODIGO AND IP.PER_IDPERSONA=VP.PER_IDPERSONA AND IP.VAL_IDVALIDADOR = 110) HECHO_VICTIMIZANTE_10,
(SELECT IP.PRE_VALOR FROM GIC_N_VALIDADORESXPERSONA IP WHERE IP.HOG_CODIGO=VP.HOG_CODIGO AND IP.PER_IDPERSONA=VP.PER_IDPERSONA AND IP.VAL_IDVALIDADOR = 111) HECHO_VICTIMIZANTE_11,
(SELECT IP.PRE_VALOR FROM GIC_N_VALIDADORESXPERSONA IP WHERE IP.HOG_CODIGO=VP.HOG_CODIGO AND IP.PER_IDPERSONA=VP.PER_IDPERSONA AND IP.VAL_IDVALIDADOR = 112) HECHO_VICTIMIZANTE_12,
(SELECT IP.PRE_VALOR FROM GIC_N_VALIDADORESXPERSONA IP WHERE IP.HOG_CODIGO=VP.HOG_CODIGO AND IP.PER_IDPERSONA=VP.PER_IDPERSONA AND IP.VAL_IDVALIDADOR = 113) HECHO_VICTIMIZANTE_13,
(SELECT IP.PRE_VALOR FROM GIC_N_VALIDADORESXPERSONA IP WHERE IP.HOG_CODIGO=VP.HOG_CODIGO AND IP.PER_IDPERSONA=VP.PER_IDPERSONA AND IP.VAL_IDVALIDADOR = 114) HECHO_VICTIMIZANTE_14,
(
  SELECT
  CASE WHEN RE.RES_IDRESPUESTA = '3822' THEN 'NINGUNA'
  WHEN RE.RES_IDRESPUESTA = '3819' THEN 'Actualizacion de Nombres y/o Apellidos'
  WHEN RE.RES_IDRESPUESTA = '3820' THEN 'Actualizacion de Documento de Identidad'
  WHEN RE.RES_IDRESPUESTA = '3821' THEN 'Actualizacion Fecha de Nacimiento'
  ELSE ''
  END NOVEDAD
  FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (3819,3820,3821,3822)
)   NOVEDAD_RUV,
( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA = '3802' THEN 'Solicita documento de identidad'
 WHEN  RE.RES_IDRESPUESTA = '3803' THEN 'Solicita documento de identidad'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (3802,3803)) NECESIDAD_IDENTIFICADA,
 ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA = '3802' THEN 'Identificacion'
 WHEN  RE.RES_IDRESPUESTA = '3803' THEN 'Identificacion'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (3802,3803)) MEDIDA_ASISTENCIA,
 ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA = '106' THEN 'Requiere definir situacion militar'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (106)) NECESIDAD_IDENTIFICADA_106,
 ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA = '106' THEN 'Identificacion'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (106)) MEDIDA_ASISTENCIA_106,
  ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA = '248' THEN 'Menor requiere acceso a educacion'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (248)) NECESIDAD_IDENTIFICADA_248,
   ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA = '248' THEN 'Educacion'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (248)) MEDIDA_ASISTENCIA_248,
   ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA = '3823' THEN 'Requiere acceso a educacion basica o media'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (3823)) NECESIDAD_IDENTIFICADA_3823,
   ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA = '3823' THEN 'Educacion'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (3823)) MEDIDA_ASISTENCIA_3823,
    ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA = '276' THEN 'Requiere afiliacion a salud'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (276)) NECESIDAD_IDENTIFICADA_276,
   ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA = '276' THEN 'Salud'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (276)) MEDIDA_ASISTENCIA_276,
     ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA = '3859' THEN 'Requiere acompa?amiento psicosocial'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (3859)) NECESIDAD_IDENTIFICADA_3859,
   ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA = '3859' THEN 'Rehabilitacion'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (3859)) MEDIDA_ASISTENCIA_3859,
   ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA IN (3832) THEN 'Requiere formacion titulada SENA'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (3832)) NECESIDAD_IDENTIFICADA_3832,
   ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA IN (3832) THEN 'Fuerza de trabajo'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (3832)) MEDIDA_ASISTENCIA_3832,
   ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA IN (3833) THEN 'Requiere formacion complementaria SENA'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (3833)) NECESIDAD_IDENTIFICADA_3833,
   ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA IN (3833) THEN 'Fuerza de trabajo'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (3833)) MEDIDA_ASISTENCIA_3833,
   ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA IN (3834) THEN 'Requiere educacion y/o formacion para el trabajo'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (3834)) NECESIDAD_IDENTIFICADA_3834,
   ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA IN (3834) THEN 'Fuerza de trabajo'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (3834)) MEDIDA_ASISTENCIA_3834,
   ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA IN (3835) THEN 'Requiere intermediacion laboral - SENA'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (3835)) NECESIDAD_IDENTIFICADA_3835,
   ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA IN (3835) THEN 'Fuerza de trabajo'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (3835)) MEDIDA_ASISTENCIA_3835,
   ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA IN (3836) THEN 'Requiere certificacion de competencias laborales - SENA'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (3836)) NECESIDAD_IDENTIFICADA_3836,
   ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA IN (3836) THEN 'Fuerza de trabajo'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (3836)) MEDIDA_ASISTENCIA_3836,
   ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA IN (3837) THEN 'Requiere programas de empleabilidad'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (3837)) NECESIDAD_IDENTIFICADA_3837,
   ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA IN (3837) THEN 'Fuerza de trabajo'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (3837)) MEDIDA_ASISTENCIA_3837,
   ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA IN (3838) THEN 'Requiere asistencia tecnica para fortalecimiento de negocios - SENA'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (3838)) NECESIDAD_IDENTIFICADA_3838,
   ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA IN (3838) THEN 'Fuerza de trabajo'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (3838)) MEDIDA_ASISTENCIA_3838,
   ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA IN (3839) THEN 'Requiere programas de fortalecimiento de negocios - SENA'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (3839)) NECESIDAD_IDENTIFICADA_3839,
   ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA IN (3839) THEN 'Fuerza de trabajo'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (3839)) MEDIDA_ASISTENCIA_3839,
   ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA IN (3840) THEN 'Requiere programas de Asesoria (sensibilizacion al emprendimiento - formulacion de planes de negocio)? SENA'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (3840)) NECESIDAD_IDENTIFICADA_3840,
   ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA IN (3840) THEN 'Fuerza de trabajo'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (3840)) MEDIDA_ASISTENCIA_3840,
   ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA IN (3841) THEN 'Requiere Apoyo economico para nuevos emprendimientos'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (3841)) NECESIDAD_IDENTIFICADA_3841,
   ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA IN (3841) THEN 'Fuerza de trabajo'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (3841)) MEDIDA_ASISTENCIA_3841,
   ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA IN (3842) THEN 'Requiere programas de emprendimiento'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (3842)) NECESIDAD_IDENTIFICADA_3842,
   ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA IN (3842) THEN 'Fuerza de trabajo'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (3842)) MEDIDA_ASISTENCIA_3842,
     ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA IN (3864) THEN 'Requiere reunificacion familiar'
 ELSE '' END   NECESIDAD_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (3864)) NECESIDAD_IDENTIFICADA_3864,
   ( SELECT 
 CASE WHEN  RE.RES_IDRESPUESTA IN (3864) THEN 'Reunificacion familiar'
 ELSE '' END   MEDIDA_IDENTIFICADA
 FROM GIC_N_RESPUESTASENCUESTA_C RE WHERE  RE.HOG_CODIGO=C.HOG_CODIGO AND RE.PER_IDPERSONA=C.PER_IDPERSONA AND RE.RES_IDRESPUESTA IN (3864)) MEDIDA_ASISTENCIA_3864,
  (SELECT REC.RXP_TEXTORESPUESTA FROM GIC_N_RESPUESTASENCUESTA_C REC WHERE REC.RES_IDRESPUESTA = '23' AND REC.HOG_CODIGO=C.HOG_CODIGO AND REC.PER_IDPERSONA=C.PER_IDPERSONA ) EDAD 
 

FROM  GIC_HOGAR H
JOIN GIC_MIEMBROS_HOGAR M ON H.HOG_CODIGO = M.HOG_CODIGO
JOIN GIC_PERSONA P ON P.PER_IDPERSONA=M.PER_IDPERSONA
JOIN GIC_N_VALIDADORESXPERSONA VP ON VP.HOG_CODIGO=H.HOG_CODIGO
JOIN GIC_N_RESPUESTASENCUESTA_C C ON C.HOG_CODIGO=H.HOG_CODIGO
WHERE H.HOG_CODIGO = CODHOGAR_T AND VP.PER_IDPERSONA=P.PER_IDPERSONA AND VP.HOG_CODIGO=M.HOG_CODIGO
AND VP.HOG_CODIGO=H.HOG_CODIGO AND VP.VAL_IDVALIDADOR IN (1) AND C.PER_IDPERSONA=P.PER_IDPERSONA
) x ORDER BY 2,9 ;


    Exception  when others then
    SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_CONSTANCIA','');
    SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_CONSTANCIA','');

END SP_CONSTANCIA;

--INSERTA ARCHIVO COLILLA ASOCIADO A UN CODIGO DE HOGAR.
PROCEDURE SP_INSERTA_CONSTA_FIRMADA_SAAH
  (
  pHOG_CODIGO IN VARCHAR2,
  pARC_URL IN VARCHAR2,
  pUSU_CREACION IN VARCHAR2
  )
 AS
BEGIN

 DELETE FROM GIC_N_CONSTANCIA_FIRMADA_SAAH T WHERE T.HOG_CODIGO=pHOG_CODIGO;
 COMMIT;
  INSERT INTO GIC_N_CONSTANCIA_FIRMADA_SAAH
  (HOG_CODIGO, ARC_URL, USU_USUARIOCREACION, USU_FECHACREACION)
  VALUES
  (pHOG_CODIGO,pARC_URL,pUSU_CREACION, SYSDATE);
  COMMIT;
  
  Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_INSERTA_CONSTA_FIRMADA_SAAH','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_INSERTA_CONSTA_FIRMADA_SAAH','');
  
END SP_INSERTA_CONSTA_FIRMADA_SAAH;

--DEVUELVE TIPOPERSONA  A PARTIR  DEL CODIGO DE HOGAR Y EL IDPERSONA 06/01/2020 ANDRES QUINTERO
FUNCTION FN_GET_TIPOPERSONA(pIDPERSONA IN INTEGER, pCODHOGAR IN VARCHAR2) RETURN INTEGER
 IS RESULT INTEGER;
 PTIPOPERSONA NUMBER;

 BEGIN
select COUNT(VP.VAL_IDVALIDADOR)   as TIPOPERSONA INTO  PTIPOPERSONA
from Gic_n_Validadoresxpersona VP
WHERE  VP.hog_codigo=pCODHOGAR AND VP.per_idpersona=pIDPERSONA AND VP.VAL_IDVALIDADOR IN (5001,5002,5003);
RESULT :=PTIPOPERSONA;
RETURN RESULT ;

      Exception  when others then
      return 0;      

  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'FN_GET_TIPOPERSONA','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'FN_GET_TIPOPERSONA','');       
      
  END  FN_GET_TIPOPERSONA;
  
--DEVUELVE EL TOTAL DE CUARTOS DISPONIBLES POR FAMILIA INCLUYENDO SALACOMEDOR
FUNCTION FN_GET_TOTALCUARTOSXFAMILIA(pIDPERSONA IN INTEGER, pCODHOGAR IN VARCHAR2) RETURN INTEGER
 IS RESULT INTEGER;
 PTOTALCUARTOS NUMBER;

 BEGIN
  SELECT  RES.RXP_TEXTORESPUESTA INTO PTOTALCUARTOS
  FROM gic_n_respuestasencuesta res
  WHERE res.res_idrespuesta=158 AND res.hog_codigo=pCODHOGAR AND res.per_idpersona=pIDPERSONA;
  RESULT :=PTOTALCUARTOS;
  RETURN RESULT ;

   Exception when others then
   return 0;
        

  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'FN_GET_TOTALCUARTOSXFAMILIA','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'FN_GET_TOTALCUARTOSXFAMILIA','');
        
END  FN_GET_TOTALCUARTOSXFAMILIA; 


FUNCTION FN_GET_HOGAR_CERRAD_CONSTANCIA(pCODHOGAR IN VARCHAR2) RETURN NUMBER
 IS RESULT INTEGER;
 EXISHOGAR NUMBER;

 BEGIN
  SELECT COUNT(RES.HOG_CODIGO) INTO EXISHOGAR
  FROM gic_n_respuestasencuesta_C res
  WHERE res.Hog_Codigo=pCODHOGAR;  
  RESULT :=EXISHOGAR;
  RETURN RESULT ;

   Exception    when others then
   return 0;      

  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'FN_GET_HOGAR_CERRAD_CONSTANCIA','');
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'FN_GET_HOGAR_CERRAD_CONSTANCIA','');
      
END  FN_GET_HOGAR_CERRAD_CONSTANCIA; 

--DEVUELVE EL GRUPO FAMILIAR POR CODIGO DEGHOAR
PROCEDURE SP_REPORTE_XHOGAR

(
 pCODHOGAR IN VARCHAR2,
 cur_OUT OUT gic_cursor.cursor_select
)
AS
  TESTADO NUMBER := 0;
  ESTADO NVARCHAR2(100) := '';
  CHOGAR  gic_cursor.cursor_select;
BEGIN


  SELECT COUNT(H.ESTADO) INTO TESTADO FROM GIC_HOGAR H WHERE H.HOG_CODIGO = pCODHOGAR AND H.ID_PERFIL_USUARIO IN (1230,1190) ;
  
  IF TESTADO > 0 THEN
     SELECT H.ESTADO INTO ESTADO FROM GIC_HOGAR H WHERE H.HOG_CODIGO = pCODHOGAR;     
  END IF; 
  
  IF ESTADO = 'APLAZADA' THEN
    SP_REPORTE_XHOGAR_REN(pCODHOGAR,CHOGAR);
    cur_OUT := CHOGAR;
  END IF;
  IF ESTADO = 'ACTIVA' THEN
    SP_REPORTE_XHOGAR_REN(pCODHOGAR,CHOGAR);
    cur_OUT := CHOGAR;
  END IF;
  IF ESTADO = 'ANULADA' THEN
    SP_REPORTE_XHOGAR_RENC(pCODHOGAR,CHOGAR);
    cur_OUT := CHOGAR;
  END IF;
  IF ESTADO = 'CERRADA' THEN
    SP_REPORTE_XHOGAR_RENC(pCODHOGAR,CHOGAR);
    cur_OUT := CHOGAR;
  END IF;
  
  IF TESTADO  = 0 THEN
    OPEN cur_OUT FOR
         SELECT '0' PER_IDPERSONA, 'ENTREVISTA NO PERTENECE A SAAH' NOMBRE, '' TIPO_DOCUMENTO,'' NUMERO_DOCUMENTO,
         '' PER_ENCUESTADA, '' ESTADO_ENCUESTA, '' FECHA_CREACION, '' USUARIO_CREACION,
         '' HOG_CODIGO FROM DUAL;
    END IF;
      
  Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_REPORTE_XHOGAR',pCODHOGAR);
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_REPORTE_XHOGAR',pCODHOGAR);
  
END SP_REPORTE_XHOGAR;


PROCEDURE SP_REPORTE_XHOGAR_RENC

(
  pCODHOGAR IN VARCHAR2,
 cur_OUT OUT gic_cursor.cursor_select
)
AS
  
BEGIN
  
  OPEN cur_OUT FOR
      SELECT MH.PER_IDPERSONA,
      (
      SELECT C.RXP_TEXTORESPUESTA FROM GIC_N_RESPUESTASENCUESTA_C C WHERE C.HOG_CODIGO=H.HOG_CODIGO AND C.PER_IDPERSONA=MH.PER_IDPERSONA
      AND C.RES_IDRESPUESTA IN (19)) ||' '||

      (
      SELECT C.RXP_TEXTORESPUESTA FROM GIC_N_RESPUESTASENCUESTA_C C WHERE C.HOG_CODIGO=H.HOG_CODIGO AND C.PER_IDPERSONA=MH.PER_IDPERSONA
      AND C.RES_IDRESPUESTA IN (20)) ||' '||

      (
      SELECT C.RXP_TEXTORESPUESTA FROM GIC_N_RESPUESTASENCUESTA_C C WHERE C.HOG_CODIGO=H.HOG_CODIGO AND C.PER_IDPERSONA=MH.PER_IDPERSONA
      AND C.RES_IDRESPUESTA IN (21)) ||' '||

      (
      SELECT C.RXP_TEXTORESPUESTA FROM GIC_N_RESPUESTASENCUESTA_C C WHERE C.HOG_CODIGO=H.HOG_CODIGO AND C.PER_IDPERSONA=MH.PER_IDPERSONA
      AND C.RES_IDRESPUESTA IN (22)) NOMBRE,

      (
      SELECT
      CASE 
        WHEN C.RES_IDRESPUESTA = 93 THEN 'Cedula de ciudadania / Contrase?a'
        WHEN C.RES_IDRESPUESTA = 94 THEN 'Cedula de extranjeria'
        WHEN C.RES_IDRESPUESTA = 95 THEN 'Tarjeta de identidad'
        WHEN C.RES_IDRESPUESTA = 96 THEN 'Registro civil/NUIP'
        WHEN C.RES_IDRESPUESTA = 97 THEN 'Contrase?a'
        WHEN C.RES_IDRESPUESTA = 98 THEN 'Otro'
        WHEN C.RES_IDRESPUESTA = 99 THEN 'No sabe'
        WHEN C.RES_IDRESPUESTA = 100 THEN 'Indocumentado'
        WHEN C.RES_IDRESPUESTA = 3750 THEN 'Certificado de identificacion por parte del cabildo'
        WHEN C.RES_IDRESPUESTA = 3751 THEN 'Certificado de identificacion/pertenencia por parte del consejo comunitario'
        WHEN C.RES_IDRESPUESTA = 3854 THEN 'Cedula de ciudadania/contrase?a'
        WHEN C.RES_IDRESPUESTA = 3853 THEN 'Cedula de ciudadania/contrase?a'
        WHEN C.RES_IDRESPUESTA = 3852 THEN 'Cedula de ciudadania/contrase?a'
        WHEN C.RES_IDRESPUESTA = 3805 THEN 'Certificado de pertenencia etnica'
        WHEN C.RES_IDRESPUESTA = 3804 THEN 'Recien nacido'
        WHEN C.RES_IDRESPUESTA = 3803 THEN 'Menor sin identificar'
        WHEN C.RES_IDRESPUESTA = 3802 THEN 'Adulto sin identificar'
        WHEN C.RES_IDRESPUESTA = 3801 THEN 'Pasaporte'
        WHEN C.RES_IDRESPUESTA = 3800 THEN 'Permiso temporal de permanencia'
        WHEN C.RES_IDRESPUESTA = 3799 THEN 'Permiso especial de permanencia'
      ELSE '' END TIPODOCUMENTO FROM GIC_N_RESPUESTASENCUESTA_C C WHERE C.HOG_CODIGO=H.HOG_CODIGO AND C.PER_IDPERSONA=MH.PER_IDPERSONA
        
      AND C.RES_IDRESPUESTA IN (93,94,95,96,97,98,99,100,3751,3750,3854,3853,3852,3805,3804,3803,3802,3801,3800,3799)) TIPO_DOCUMENTO,
      (
      SELECT C.RXP_TEXTORESPUESTA FROM GIC_N_RESPUESTASENCUESTA_C C WHERE C.HOG_CODIGO=H.HOG_CODIGO AND C.PER_IDPERSONA=MH.PER_IDPERSONA
      AND C.RES_IDRESPUESTA IN (101)) NUMERO_DOCUMENTO,

      (SELECT T.PRE_VALOR FROM GIC_N_VALIDADORESXPERSONA T WHERE T.HOG_CODIGO = pCODHOGAR AND T.VAL_IDVALIDADOR IN (5001,5002,5003,5004) AND T.PER_IDPERSONA=MH.PER_IDPERSONA ) PER_ENCUESTADA,
      
      H.ESTADO ESTADO_ENCUESTA, H.USU_FECHACREACION FECHA_CREACION, H.USU_USUARIOCREACION USUARIO_CREACION,

      H.HOG_CODIGO
      FROM GIC_HOGAR H, GIC_MIEMBROS_HOGAR MH

      WHERE H.HOG_CODIGO=MH.HOG_CODIGO
      AND H.HOG_CODIGO= pCODHOGAR AND H.ID_PERFIL_USUARIO IN (1230,1190);


      
  Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_REPORTE_XHOGAR_RENC',pCODHOGAR);
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_REPORTE_XHOGAR_RENC',pCODHOGAR);
  
END SP_REPORTE_XHOGAR_RENC;


PROCEDURE SP_REPORTE_XHOGAR_REN

(
  pCODHOGAR IN VARCHAR2,
 cur_OUT OUT gic_cursor.cursor_select
)
AS
  
BEGIN
  
  OPEN cur_OUT FOR
  SELECT MH.PER_IDPERSONA,
    (
    SELECT C.RXP_TEXTORESPUESTA FROM GIC_N_RESPUESTASENCUESTA C WHERE C.HOG_CODIGO=H.HOG_CODIGO AND C.PER_IDPERSONA=MH.PER_IDPERSONA
    AND C.RES_IDRESPUESTA IN (19)) ||' '||

    (
    SELECT C.RXP_TEXTORESPUESTA FROM GIC_N_RESPUESTASENCUESTA C WHERE C.HOG_CODIGO=H.HOG_CODIGO AND C.PER_IDPERSONA=MH.PER_IDPERSONA
    AND C.RES_IDRESPUESTA IN (20)) ||' '||

    (
    SELECT C.RXP_TEXTORESPUESTA FROM GIC_N_RESPUESTASENCUESTA C WHERE C.HOG_CODIGO=H.HOG_CODIGO AND C.PER_IDPERSONA=MH.PER_IDPERSONA
    AND C.RES_IDRESPUESTA IN (21)) ||' '||

    (
    SELECT C.RXP_TEXTORESPUESTA FROM GIC_N_RESPUESTASENCUESTA C WHERE C.HOG_CODIGO=H.HOG_CODIGO AND C.PER_IDPERSONA=MH.PER_IDPERSONA
    AND C.RES_IDRESPUESTA IN (22)) NOMBRE,

    (
    SELECT
    CASE 
      WHEN C.RES_IDRESPUESTA = 93 THEN 'Cedula de ciudadania / Contrase?a'
      WHEN C.RES_IDRESPUESTA = 94 THEN 'Cedula de extranjeria'
      WHEN C.RES_IDRESPUESTA = 95 THEN 'Tarjeta de identidad'
      WHEN C.RES_IDRESPUESTA = 96 THEN 'Registro civil/NUIP'
      WHEN C.RES_IDRESPUESTA = 97 THEN 'Contrase?a'
      WHEN C.RES_IDRESPUESTA = 98 THEN 'Otro'
      WHEN C.RES_IDRESPUESTA = 99 THEN 'No sabe'
      WHEN C.RES_IDRESPUESTA = 100 THEN 'Indocumentado'
      WHEN C.RES_IDRESPUESTA = 3750 THEN 'Certificado de identificacion por parte del cabildo'
      WHEN C.RES_IDRESPUESTA = 3751 THEN 'Certificado de identificacion/pertenencia por parte del consejo comunitario'
      WHEN C.RES_IDRESPUESTA = 3854 THEN 'Cedula de ciudadania/contrase?a'
      WHEN C.RES_IDRESPUESTA = 3853 THEN 'Cedula de ciudadania/contrase?a'
      WHEN C.RES_IDRESPUESTA = 3852 THEN 'Cedula de ciudadania/contrase?a'
      WHEN C.RES_IDRESPUESTA = 3805 THEN 'Certificado de pertenencia etnica'
      WHEN C.RES_IDRESPUESTA = 3804 THEN 'Recien nacido'
      WHEN C.RES_IDRESPUESTA = 3803 THEN 'Menor sin identificar'
      WHEN C.RES_IDRESPUESTA = 3802 THEN 'Adulto sin identificar'
      WHEN C.RES_IDRESPUESTA = 3801 THEN 'Pasaporte'
      WHEN C.RES_IDRESPUESTA = 3800 THEN 'Permiso temporal de permanencia'
      WHEN C.RES_IDRESPUESTA = 3799 THEN 'Permiso especial de permanencia'
    ELSE '' END TIPODOCUMENTO FROM GIC_N_RESPUESTASENCUESTA C WHERE C.HOG_CODIGO=H.HOG_CODIGO AND C.PER_IDPERSONA=MH.PER_IDPERSONA
      
    AND C.RES_IDRESPUESTA IN (93,94,95,96,97,98,99,100,3751,3750,3854,3853,3852,3805,3804,3803,3802,3801,3800,3799)) TIPO_DOCUMENTO,
    (
    SELECT C.RXP_TEXTORESPUESTA FROM GIC_N_RESPUESTASENCUESTA C WHERE C.HOG_CODIGO=H.HOG_CODIGO AND C.PER_IDPERSONA=MH.PER_IDPERSONA
    AND C.RES_IDRESPUESTA IN (101)) NUMERO_DOCUMENTO,

    (SELECT T.PRE_VALOR FROM GIC_N_VALIDADORESXPERSONA T WHERE T.HOG_CODIGO = pCODHOGAR AND T.VAL_IDVALIDADOR IN (5001,5002,5003,5004) AND T.PER_IDPERSONA=MH.PER_IDPERSONA ) PER_ENCUESTADA,    
    
    H.ESTADO ESTADO_ENCUESTA, H.USU_FECHACREACION FECHA_CREACION, H.USU_USUARIOCREACION USUARIO_CREACION,

    H.HOG_CODIGO
    FROM GIC_HOGAR H, GIC_MIEMBROS_HOGAR MH

    WHERE H.HOG_CODIGO=MH.HOG_CODIGO
    AND H.HOG_CODIGO= pCODHOGAR AND H.ID_PERFIL_USUARIO IN (1230,1190);
      
  Exception  when others then
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_backtrace,null,null,NULL,'SP_REPORTE_XHOGAR_REN',pCODHOGAR);
  SP_GEN_LOG_ERROR(SYSDATE,DBMS_UTILITY.format_error_stack,null,null,NULL,'SP_REPORTE_XHOGAR_REN',pCODHOGAR);
  
END SP_REPORTE_XHOGAR_REN;


END GIC_N_CARACTERIZACION;

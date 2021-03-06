CREATE OR REPLACE PACKAGE PKG_GESTION_ENCUESTADORMOVIL IS

PROCEDURE GIC_AGREGAR_PERSONA(P_Per_Idpersona NUMBER, P_apellido1 NVARCHAR2,P_apellido2 NVARCHAR2,P_nombre1 NVARCHAR2,P_nombre2 NVARCHAR2,
  P_tipoDoc NVARCHAR2, P_documento NVARCHAR2,P_fecNacimiento NVARCHAR2,P_Estado NVARCHAR2,P_usu_usuariocreacion NVARCHAR2,
  P_Usu_FechaCreacion NVARCHAR2,V_SALIDA OUT NVARCHAR2,
  V_VALSECUENCIA OUT NUMBER);

PROCEDURE GIC_AGREGAR_HOGAR(P_hog_codigo NVARCHAR2,P_usu_usuariocreacion NVARCHAR2,P_usu_idusuario NUMBER,P_usu_fechacreacion NVARCHAR2,
                            P_estado NVARCHAR2,
                            V_SALIDA OUT NVARCHAR2);


PROCEDURE GIC_AGREGAR_CAPITULOSTER (P_hog_codigo NVARCHAR2,P_id_tema NUMBER,P_usu_usuariocreacion NVARCHAR2,P_usu_fechacreacion NVARCHAR2, V_SALIDA OUT NVARCHAR2);

PROCEDURE GIC_AGREGAR_MIEMBROSHOGAR(p_P_hog_codigo NVARCHAR2,P_Per_Idpersona NUMBER,P_usu_usuariocreacion NVARCHAR2,
  P_usu_fechacreacion NVARCHAR2,P_per_encuestada NVARCHAR2, P_documento NVARCHAR2, P_idpersona_encomu NUMBER, V_SALIDA OUT NVARCHAR2);

PROCEDURE GIC_AGREGAR_RESPUESTAENCUESTA(P_hog_codigo NVARCHAR2,P_Per_Idpersona NUMBER,P_Res_IdRespuesta NUMBER,P_Tipo_Pregunta NVARCHAR2,
  P_Usu_Usuariocreacion NVARCHAR2,P_Usu_FechaCreacion NVARCHAR2,P_Ins_Idinstrumento NUMBER,P_Rxp_TextoRespuesta NVARCHAR2,V_SALIDA OUT NVARCHAR2);


--Genera c�digo aleatoria de 5 caracteres
FUNCTION FN_GET_GENERAR_CODIGO_ENCUESTA RETURN VARCHAR2;

FUNCTION FN_GET_CODIGOENCUESTA RETURN VARCHAR2;

FUNCTION FN_CORREGIR_TEXTOS RETURN VARCHAR2;

PROCEDURE GIC_N_BORRAR_RES_DUP;

--INSERTAR Y DEVUELVE  HOGAR
/*FUNCTION GET_CODIGOHOGAR  (USUA_CREACION IN NVARCHAR2,    ID_USUARIO IN INTEGER )  RETURN VARCHAR2;*/

END PKG_GESTION_ENCUESTADORMOVIL;

 

 
CREATE OR REFRESH STREAMING TABLE ${catalogo}.${schema_silver}.unidades_consumidoras
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
AS SELECT
  id_uc,
  id_conjunto,
  id_cliente,
  nome_conjunto,
  municipio,
  lower(trim(classe_consumo))                         AS classe_consumo,
  coalesce(nullif(trim(bairro), ''), 'nao informado') AS bairro,
  subgrupo_tarifario,
  tensao_nominal_v,
  possui_medidor_inteligente,
  situacao,
  data_ligacao,
  consumo_medio_kwh_dia,
  arquivo_origem,
  ingerido_bronze_em
FROM STREAM(${catalogo}.${schema_bronze}.unidades_consumidoras)
WHERE id_uc IS NOT NULL AND id_conjunto IS NOT NULL;

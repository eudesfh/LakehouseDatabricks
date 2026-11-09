-- AVISO: cada base ocupa um único arquivo Parquet sobrescrito ao ser regerado.
-- allowOverwrites => true faz o Auto Loader reprocessar o arquivo trocado, mas
-- streaming table é append-only: as linhas antigas permanecem.
-- Solução: após regerar os dados, rode o pipeline com full refresh.

CREATE OR REFRESH STREAMING TABLE ${catalogo}.${schema_bronze}.unidades_consumidoras
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
AS SELECT
  *,
  _metadata.file_path AS arquivo_origem,
  current_timestamp()  AS ingerido_bronze_em
FROM STREAM read_files(
  '${volume_landing}/unidades_consumidoras/',
  format          => 'parquet',
  allowOverwrites => true
);

CREATE OR REFRESH STREAMING TABLE ${catalogo}.${schema_bronze}.interrupcoes
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
AS SELECT
  *,
  _metadata.file_path AS arquivo_origem,
  current_timestamp()  AS ingerido_bronze_em
FROM STREAM read_files(
  '${volume_landing}/interrupcoes/',
  format          => 'parquet',
  allowOverwrites => true
);

CREATE OR REFRESH STREAMING TABLE ${catalogo}.${schema_bronze}.consumo_diario
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
AS SELECT
  *,
  _metadata.file_path AS arquivo_origem,
  current_timestamp()  AS ingerido_bronze_em
FROM STREAM read_files(
  '${volume_landing}/consumo_diario/',
  format          => 'parquet',
  allowOverwrites => true
);

CREATE OR REFRESH STREAMING TABLE ${catalogo}.${schema_bronze}.chamados
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
AS SELECT
  *,
  _metadata.file_path AS arquivo_origem,
  current_timestamp()  AS ingerido_bronze_em
FROM STREAM read_files(
  '${volume_landing}/chamados/',
  format          => 'parquet',
  allowOverwrites => true
);

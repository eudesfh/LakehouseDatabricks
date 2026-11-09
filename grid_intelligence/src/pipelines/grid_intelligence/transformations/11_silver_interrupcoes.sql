-- Religador automatico: galho na rede dispara a protecao, desarme em segundos e
-- religamento automatico. O consumidor ve a luz piscar — nao e falta de energia.
-- A RN-01 exige duracao >= duracao_minima_interrupcao_min minutos para contar no DEC/FEC.

CREATE OR REFRESH STREAMING TABLE ${catalogo}.${schema_silver}.interrupcoes_validas
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')
AS SELECT
  id_interrupcao,
  id_conjunto,
  causa,
  equipamento,
  tipo,
  inicio,
  fim,
  duracao_minutos,
  qtd_ucs_afetadas,
  to_date(inicio)                              AS data_evento,
  date_trunc('MONTH', inicio)                  AS mes_apuracao,
  duracao_minutos / 60.0                       AS duracao_horas,
  (duracao_minutos / 60.0) * qtd_ucs_afetadas AS uc_horas_interrompidas,
  causa = 'climatica'                          AS causa_climatica,
  tipo  = 'programada'                         AS programada,
  arquivo_origem,
  ingerido_bronze_em
FROM STREAM(${catalogo}.${schema_bronze}.interrupcoes)
WHERE duracao_minutos >= ${duracao_minima_interrupcao_min};

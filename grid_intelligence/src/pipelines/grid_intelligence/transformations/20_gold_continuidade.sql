CREATE OR REFRESH MATERIALIZED VIEW ${catalogo}.${schema_gold}.continuidade_conjunto_mes
COMMENT 'Insumos de continuidade do fornecimento por conjunto e mes. Contem numeradores e denominadores para DEC e FEC — a divisao e feita pela metric view continuidade_metricas, garantindo uma unica definicao no sistema (RN-04). Ausencia de coluna dec_horas e intencional.'
AS SELECT
  i.id_conjunto,
  u.nome_conjunto,
  u.municipio,
  i.mes_apuracao,
  u.total_ucs,
  sum(i.uc_horas_interrompidas)   AS uc_horas_interrompidas,
  sum(i.qtd_ucs_afetadas)         AS uc_interrupcoes,
  count(*)                        AS qtd_interrupcoes,
  count_if(i.causa_climatica)     AS qtd_interrupcoes_climaticas,
  count_if(i.programada)          AS qtd_interrupcoes_programadas,
  max(i.duracao_horas)            AS maior_duracao_horas
FROM ${catalogo}.${schema_silver}.interrupcoes_validas i
INNER JOIN (
  SELECT id_conjunto, any_value(nome_conjunto) AS nome_conjunto,
         any_value(municipio) AS municipio, count(*) AS total_ucs
  FROM ${catalogo}.${schema_silver}.unidades_consumidoras
  GROUP BY id_conjunto
) u ON i.id_conjunto = u.id_conjunto
GROUP BY i.id_conjunto, u.nome_conjunto, u.municipio, i.mes_apuracao, u.total_ucs;

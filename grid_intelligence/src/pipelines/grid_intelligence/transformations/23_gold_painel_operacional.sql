-- FULL OUTER JOIN entre os tres blocos: dia com interrupcao e sem chamado existe,
-- e dia com chamado e sem interrupcao tambem. Um JOIN comum comeria essas linhas.

CREATE OR REFRESH MATERIALIZED VIEW ${catalogo}.${schema_gold}.painel_operacional_dia
COMMENT 'Painel operacional diario por conjunto — costura interrupcoes, chamados, consumo e prioridades de inspecao. Coluna acao_recomendada ordena as decisoes por gravidade: saude > ouvidoria > rede > inspecao.'
AS WITH interrupcoes AS (
  SELECT
    id_conjunto,
    data_evento                        AS data,
    count(*)                           AS qtd_interrupcoes,
    sum(uc_horas_interrompidas)        AS uc_horas_interrompidas,
    sum(qtd_ucs_afetadas)              AS ucs_afetadas,
    max(duracao_horas)                 AS maior_interrupcao_horas,
    count_if(causa_climatica)          AS interrupcoes_climaticas
  FROM ${catalogo}.${schema_silver}.interrupcoes_validas
  GROUP BY id_conjunto, data_evento
),
chamados AS (
  SELECT
    id_conjunto,
    data_chamado                       AS data,
    count(*)                           AS qtd_chamados,
    count_if(sentimento = 'negative')  AS chamados_negativos,
    count_if(ameacou_ouvidoria)        AS mencoes_ouvidoria,
    count_if(risco_a_saude)            AS chamados_risco_saude,
    count_if(urgencia = 'alta')        AS chamados_urgencia_alta
  FROM ${catalogo}.${schema_silver}.chamados_enriquecidos
  GROUP BY id_conjunto, data_chamado
),
consumo AS (
  SELECT
    id_conjunto,
    data,
    round(avg(consumo_kwh), 2)         AS consumo_medio_kwh,
    count(*)                           AS ucs_com_leitura
  FROM ${catalogo}.${schema_silver}.consumo_diario
  GROUP BY id_conjunto, data
),
prioridades AS (
  SELECT
    id_conjunto,
    count_if(prioridade_inspecao = 'alta')  AS ucs_prioridade_alta,
    count_if(prioridade_inspecao = 'media') AS ucs_prioridade_media
  FROM ${catalogo}.${schema_gold}.prioridade_inspecao_uc
  GROUP BY id_conjunto
),
conjuntos AS (
  SELECT id_conjunto, any_value(nome_conjunto) AS nome_conjunto, any_value(municipio) AS municipio
  FROM ${catalogo}.${schema_silver}.unidades_consumidoras
  GROUP BY id_conjunto
)
SELECT
  coalesce(i.id_conjunto, ch.id_conjunto, c.id_conjunto)  AS id_conjunto,
  cj.nome_conjunto,
  cj.municipio,
  coalesce(i.data, ch.data, c.data)                       AS data,
  coalesce(i.qtd_interrupcoes, 0)                         AS qtd_interrupcoes,
  coalesce(i.uc_horas_interrompidas, 0.0)                 AS uc_horas_interrompidas,
  coalesce(i.ucs_afetadas, 0)                             AS ucs_afetadas,
  i.maior_interrupcao_horas,
  coalesce(i.interrupcoes_climaticas, 0)                  AS interrupcoes_climaticas,
  coalesce(ch.qtd_chamados, 0)                            AS qtd_chamados,
  coalesce(ch.chamados_negativos, 0)                      AS chamados_negativos,
  coalesce(ch.mencoes_ouvidoria, 0)                       AS mencoes_ouvidoria,
  coalesce(ch.chamados_risco_saude, 0)                    AS chamados_risco_saude,
  coalesce(ch.chamados_urgencia_alta, 0)                  AS chamados_urgencia_alta,
  c.consumo_medio_kwh,
  c.ucs_com_leitura,
  coalesce(p.ucs_prioridade_alta, 0)                      AS ucs_prioridade_alta,
  coalesce(p.ucs_prioridade_media, 0)                     AS ucs_prioridade_media,
  CASE
    WHEN coalesce(ch.chamados_risco_saude, 0) > 0
      THEN concat('Atender urgencia de saude: ', cast(ch.chamados_risco_saude AS string), ' chamado(s)')
    WHEN coalesce(ch.mencoes_ouvidoria, 0) > 0
      THEN concat('Tratar risco de ouvidoria: ', cast(ch.mencoes_ouvidoria AS string), ' mencao(oes)')
    WHEN coalesce(i.uc_horas_interrompidas, 0) > 0
      THEN concat('Verificar impacto de rede: ', cast(coalesce(i.qtd_interrupcoes, 0) AS string), ' interrupcao(oes)')
    WHEN coalesce(p.ucs_prioridade_alta, 0) > 0
      THEN concat('Programar ', cast(p.ucs_prioridade_alta AS string), ' inspecao(oes) prioritaria(s)')
    ELSE 'Monitoramento de rotina'
  END AS acao_recomendada
FROM interrupcoes  i
FULL OUTER JOIN chamados ch ON i.id_conjunto = ch.id_conjunto AND i.data = ch.data
FULL OUTER JOIN consumo  c  ON coalesce(i.id_conjunto, ch.id_conjunto) = c.id_conjunto
                            AND coalesce(i.data, ch.data) = c.data
LEFT JOIN prioridades p  ON coalesce(i.id_conjunto, ch.id_conjunto, c.id_conjunto) = p.id_conjunto
LEFT JOIN conjuntos   cj ON coalesce(i.id_conjunto, ch.id_conjunto, c.id_conjunto) = cj.id_conjunto;

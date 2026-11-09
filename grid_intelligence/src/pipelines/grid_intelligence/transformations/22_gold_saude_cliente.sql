CREATE OR REFRESH MATERIALIZED VIEW ${catalogo}.${schema_gold}.saude_cliente
COMMENT 'Perfil de risco de cada cliente baseado no historico de chamados. Identifica clientes em rota de reclamacao na ouvidoria antes que a reclamacao seja registrada. Ultima fala vem do texto anonimizado (RN-09).'
AS WITH base AS (
  SELECT *,
    max(data_chamado) OVER () AS max_data_dataset
  FROM ${catalogo}.${schema_silver}.chamados_enriquecidos
)
SELECT
  id_cliente,
  any_value(id_conjunto)                                                                        AS id_conjunto,
  any_value(nome_conjunto)                                                                      AS nome_conjunto,
  any_value(bairro)                                                                             AS bairro,
  count(*)                                                                                      AS qtd_chamados,
  count(distinct id_uc)                                                                         AS qtd_ucs_com_chamado,
  count_if(sentimento = 'negative')                                                             AS qtd_chamados_negativos,
  round(100.0 * count_if(sentimento = 'negative') / count(*), 1)                               AS proporcao_negativa,
  count_if(ameacou_ouvidoria)                                                                   AS qtd_mencoes_ouvidoria,
  count_if(risco_a_saude)                                                                       AS qtd_chamados_risco_saude,
  count_if(urgencia = 'alta')                                                                   AS qtd_urgencia_alta,
  count_if(data_chamado >= max_data_dataset - INTERVAL 30 DAYS) >= 3                           AS reincidente,
  mode(motivo)                                                                                  AS motivo_predominante,
  max_by(equipamento_citado, data_chamado)                                                      AS ultimo_equipamento_citado,
  max_by(transcricao_anonimizada, data_chamado)                                                 AS ultima_fala,
  min(data_chamado)                                                                             AS primeiro_chamado_em,
  max(data_chamado)                                                                             AS ultimo_chamado_em,
  CASE
    WHEN count_if(ameacou_ouvidoria) > 0                                                       THEN 'alto'
    WHEN count_if(data_chamado >= max_data_dataset - INTERVAL 30 DAYS) >= 3
         AND count_if(sentimento = 'negative') >= 2                                            THEN 'alto'
    WHEN count_if(risco_a_saude) > 0                                                           THEN 'alto'
    WHEN count_if(sentimento = 'negative') >= 2                                                THEN 'medio'
    WHEN count_if(data_chamado >= max_data_dataset - INTERVAL 30 DAYS) >= 3                   THEN 'medio'
    ELSE 'baixo'
  END                                                                                           AS risco_ouvidoria
FROM base
GROUP BY id_cliente;

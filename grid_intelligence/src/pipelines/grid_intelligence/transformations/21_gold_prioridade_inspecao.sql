-- RN-07: a saida e prioridade de inspecao, nunca rotulo de irregularidade.
-- Queda de consumo tambem e mudanca de morador, imovel desocupado, defeito de medidor.
-- A diferenca e juridica — nenhuma coluna deste arquivo usa fraude, furto ou culpado.

CREATE OR REFRESH MATERIALIZED VIEW ${catalogo}.${schema_gold}.prioridade_inspecao_uc
COMMENT 'Prioridade de inspecao de campo por UC candidata a anomalia de consumo. Aplica os dois eixos da RN-06: queda contra o proprio baseline E vizinhanca estavel. Saida e alta/media/baixa — nunca acusacao (RN-07).'
AS WITH sinal AS (
  SELECT c.id_uc
  FROM ${catalogo}.${schema_silver}.consumo_diario c
  CROSS JOIN (SELECT max(data) AS mx FROM ${catalogo}.${schema_silver}.consumo_diario)
  WHERE c.data > mx - INTERVAL 30 DAYS AND c.sinal_violacao_medidor = 'true'
  GROUP BY c.id_uc
)
SELECT
  b.id_uc,
  b.id_conjunto,
  u.nome_conjunto,
  u.bairro,
  u.classe_consumo,
  b.consumo_medio_baseline_kwh,
  b.consumo_medio_recente_kwh,
  b.dias_baseline,
  b.dias_recentes,
  b.variacao_pct_uc                                                         AS variacao_da_uc,
  b.variacao_pct_conjunto                                                   AS variacao_do_conjunto,
  b.variacao_pct_uc < -${limiar_queda_uc}                                  AS caiu_contra_si,
  abs(b.variacao_pct_conjunto) <= ${faixa_estabilidade_conjunto}           AS vizinhanca_estavel,
  (b.variacao_pct_uc < -${limiar_queda_uc}
    AND abs(b.variacao_pct_conjunto) <= ${faixa_estabilidade_conjunto})    AS atende_os_dois_eixos,
  s.id_uc IS NOT NULL                                                       AS sinal_violacao_recente,
  CASE
    WHEN b.variacao_pct_uc < -${limiar_queda_uc}
      AND abs(b.variacao_pct_conjunto) <= ${faixa_estabilidade_conjunto}
      AND s.id_uc IS NOT NULL                                               THEN 'alta'
    WHEN b.variacao_pct_uc < -${limiar_queda_uc}
      AND abs(b.variacao_pct_conjunto) <= ${faixa_estabilidade_conjunto}   THEN 'media'
    WHEN s.id_uc IS NOT NULL                                               THEN 'media'
    ELSE 'baixa'
  END                                                                       AS prioridade_inspecao,
  CASE
    WHEN b.variacao_pct_uc < -${limiar_queda_uc}
      AND abs(b.variacao_pct_conjunto) <= ${faixa_estabilidade_conjunto}
      THEN concat('Queda de ', cast(abs(round(b.variacao_pct_uc, 1)) AS string),
                  '% no consumo enquanto vizinhanca permaneceu estavel (',
                  cast(round(b.variacao_pct_conjunto, 1) AS string), '%)')
    WHEN abs(b.variacao_pct_conjunto) > ${faixa_estabilidade_conjunto}
      THEN concat('Queda acompanhou a vizinhanca (variacao conjunto: ',
                  cast(round(b.variacao_pct_conjunto, 1) AS string), '%) - evento de rede')
    ELSE concat('Variacao de ', cast(round(b.variacao_pct_uc, 1) AS string),
                '% no consumo — sinal de medidor detectado')
  END                                                                       AS motivo_observado
FROM ${catalogo}.${schema_silver}.baseline_consumo b
INNER JOIN ${catalogo}.${schema_silver}.unidades_consumidoras u ON b.id_uc = u.id_uc
LEFT JOIN sinal s ON b.id_uc = s.id_uc
WHERE b.variacao_pct_uc < -${limiar_queda_uc} OR s.id_uc IS NOT NULL;

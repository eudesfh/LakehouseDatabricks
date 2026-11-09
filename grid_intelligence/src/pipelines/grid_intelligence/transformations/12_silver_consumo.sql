-- silver.consumo_diario: descarta leituras invalidas e mantém o registro mais recente
-- por chave (id_uc, data) para eliminar reenvios do concentrador.
-- O limite físico e definido aqui — quem recebe a telemetria estabelece o plausivel.

CREATE OR REFRESH MATERIALIZED VIEW ${catalogo}.${schema_silver}.consumo_diario
AS SELECT
  c.id_uc,
  c.data,
  c.consumo_kwh,
  c.horas_com_leitura,
  c.sinal_violacao_medidor,
  u.id_conjunto,
  u.id_cliente,
  u.bairro,
  u.classe_consumo
FROM ${catalogo}.${schema_bronze}.consumo_diario c
INNER JOIN ${catalogo}.${schema_silver}.unidades_consumidoras u ON c.id_uc = u.id_uc
WHERE c.consumo_kwh > 0
  AND c.consumo_kwh <= CASE u.classe_consumo
    WHEN 'residencial' THEN 150
    WHEN 'rural'       THEN 500
    WHEN 'comercial'   THEN 2000
    WHEN 'industrial'  THEN 10000
    ELSE 2000
  END
QUALIFY row_number() OVER (PARTITION BY c.id_uc, c.data ORDER BY c.ingerido_em DESC) = 1;

-- Ancora no maior dia do dataset, nunca em current_date(): o dataset e sintetico e
-- current_date() faria a janela deslizar para fora do dado, devolvendo tabela vazia.

CREATE OR REFRESH MATERIALIZED VIEW ${catalogo}.${schema_silver}.baseline_consumo
AS WITH ref AS (
  SELECT max(data) AS max_data FROM ${catalogo}.${schema_silver}.consumo_diario
),
por_uc AS (
  SELECT
    c.id_uc,
    c.id_conjunto,
    avg(c.consumo_kwh) FILTER (WHERE c.data >  r.max_data - INTERVAL 30  DAYS) AS media_recente_kwh,
    avg(c.consumo_kwh) FILTER (WHERE c.data <= r.max_data - INTERVAL 30  DAYS
                                 AND c.data >  r.max_data - INTERVAL 120 DAYS) AS media_baseline_kwh,
    count(1)           FILTER (WHERE c.data >  r.max_data - INTERVAL 30  DAYS) AS dias_recentes,
    count(1)           FILTER (WHERE c.data <= r.max_data - INTERVAL 30  DAYS
                                 AND c.data >  r.max_data - INTERVAL 120 DAYS) AS dias_baseline
  FROM ${catalogo}.${schema_silver}.consumo_diario c
  CROSS JOIN ref r
  GROUP BY c.id_uc, c.id_conjunto
),
por_conjunto AS (
  SELECT
    id_conjunto,
    avg(media_recente_kwh)  AS media_recente_conjunto_kwh,
    avg(media_baseline_kwh) AS media_baseline_conjunto_kwh
  FROM por_uc
  WHERE media_recente_kwh IS NOT NULL AND media_baseline_kwh IS NOT NULL
  GROUP BY id_conjunto
)
SELECT
  p.id_uc,
  p.id_conjunto,
  p.media_baseline_kwh                                                                   AS consumo_medio_baseline_kwh,
  p.media_recente_kwh                                                                    AS consumo_medio_recente_kwh,
  p.dias_baseline,
  p.dias_recentes,
  round(100.0 * (p.media_recente_kwh - p.media_baseline_kwh)
        / nullif(p.media_baseline_kwh, 0), 1)                                           AS variacao_pct_uc,
  c.media_baseline_conjunto_kwh,
  c.media_recente_conjunto_kwh,
  round(100.0 * (c.media_recente_conjunto_kwh - c.media_baseline_conjunto_kwh)
        / nullif(c.media_baseline_conjunto_kwh, 0), 1)                                  AS variacao_pct_conjunto
FROM por_uc p
JOIN por_conjunto c ON p.id_conjunto = c.id_conjunto
WHERE p.media_baseline_kwh IS NOT NULL AND p.media_recente_kwh IS NOT NULL;

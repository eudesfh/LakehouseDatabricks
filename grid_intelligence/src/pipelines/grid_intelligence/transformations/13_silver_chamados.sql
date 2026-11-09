-- ROTA DETERMINISTICA (sem IA) — extração por regex e CASE.
-- Limitacoes desta abordagem:
--   - Ironia: "Que otimo, mais um dia sem luz" vira 'positive'
--   - Sinonimo fora da lista: "fiquei no breu" nao e classificado
--   - Motivo composto: recebe um rotulo so (o primeiro que casar)
--   - Nome com apelido: replace(transcricao, nome_solicitante, ...) nao casa — risco LGPD

CREATE OR REFRESH MATERIALIZED VIEW ${catalogo}.${schema_silver}.chamados_anonimizados
AS SELECT
  b.id_chamado,
  b.id_uc,
  u.id_cliente,
  u.id_conjunto,
  u.nome_conjunto,
  u.bairro,
  u.classe_consumo,
  to_date(b.abertura) AS data_chamado,
  hour(b.abertura)    AS hora_chamado,
  b.canal,
  b.duracao_segundos,
  regexp_replace(
    regexp_replace(
      replace(b.transcricao, b.nome_solicitante, '[MASCARADO]'),
      '[0-9]{3}\\.[0-9]{3}\\.[0-9]{3}-[0-9]{2}', '[MASCARADO]'),
    '\\([0-9]{2}\\)\\s*9?[0-9]{4}-?[0-9]{4}', '[MASCARADO]'
  )                   AS transcricao_anonimizada,
  'regras_de_texto'   AS anonimizado_por,
  b.arquivo_origem,
  b.ingerido_bronze_em
FROM ${catalogo}.${schema_bronze}.chamados b
INNER JOIN ${catalogo}.${schema_silver}.unidades_consumidoras u ON b.id_uc = u.id_uc;

CREATE OR REFRESH MATERIALIZED VIEW ${catalogo}.${schema_silver}.chamados_enriquecidos
AS SELECT
  id_chamado,
  id_uc,
  id_cliente,
  id_conjunto,
  nome_conjunto,
  bairro,
  classe_consumo,
  data_chamado,
  hora_chamado,
  canal,
  duracao_segundos,
  transcricao_anonimizada,
  CASE
    WHEN transcricao_anonimizada RLIKE '(?i)nao gostei|pessimo|horrivel|inaceitavel|absurdo|revoltad|indignado|escandalo|incompetente'
      THEN 'negative'
    WHEN transcricao_anonimizada RLIKE '(?i)obrigad|agradec|otimo|excelente|parabens|muito bom|resolveu|satisfeito'
      THEN 'positive'
    ELSE 'neutral'
  END AS sentimento,
  CASE
    -- casos de saude vem antes de religacao comum: e a mesma frase com risco no meio
    WHEN transcricao_anonimizada RLIKE '(?i)dialise|oxigenio|remedio na geladeira|crianca pequena|maquina de oxigenio'
      THEN 'religacao_urgente'
    WHEN transcricao_anonimizada RLIKE '(?i)escuro|sem energia|apagou|falta de energia|sem luz|luz nao voltou'
      THEN 'falta_energia'
    WHEN transcricao_anonimizada RLIKE '(?i)piscando|oscila|queimou|tensao|voltagem'
      THEN 'oscilacao_tensao'
    WHEN transcricao_anonimizada RLIKE '(?i)releitura|estimativa|nao bate|medicao errada'
      THEN 'erro_leitura'
    WHEN transcricao_anonimizada RLIKE '(?i)conta veio|dobro|fatura subiu|fatura alta|valor alto'
      THEN 'fatura_alta'
    WHEN transcricao_anonimizada RLIKE '(?i)poste|galho|lampada da rua|arvore na rede'
      THEN 'poste_avariado'
    WHEN transcricao_anonimizada RLIKE '(?i)religacao|religar|paguei|corte indevido'
      THEN 'religacao'
    ELSE 'duvida_cadastral'
  END AS motivo,
  regexp_extract(transcricao_anonimizada,
    '(?i)(transformador|medidor|disjuntor|poste|cabo|chave|religador|subestacao)', 1
  ) AS equipamento_citado,
  transcricao_anonimizada RLIKE '(?i)oxigenio|dialise|remedio|crianca|hospital|incendio|idoso|bebe' AS risco_a_saude,
  CASE
    WHEN transcricao_anonimizada RLIKE '(?i)oxigenio|dialise|remedio|crianca|hospital|incendio|idoso'
      THEN 'alta'
    WHEN transcricao_anonimizada RLIKE '(?i)sem energia|sem luz|urgente|religar|poste caid'
      THEN 'media'
    ELSE 'baixa'
  END AS urgencia,
  transcricao_anonimizada RLIKE '(?i)ouvidoria|aneel|procon|processo' AS ameacou_ouvidoria,
  'regras_de_texto' AS enriquecido_por,
  anonimizado_por,
  arquivo_origem,
  ingerido_bronze_em
FROM ${catalogo}.${schema_silver}.chamados_anonimizados;

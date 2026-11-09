-- Armadilha 1: o corpo YAML fica dentro de $$ e nao passa por substituicao de parametro.
-- Por isso o catalogo entra via USE CATALOG IDENTIFIER(:catalogo) e os nomes dentro do YAML
-- sao simples, sem qualificacao.
-- Armadilha 2: nenhum ponto e virgula dentro do bloco $$...$$. Um ; no meio de qualquer
-- frase — inclusive em comment — corta o CREATE VIEW ao meio e o erro parece YAML malformado.
-- Armadilha 3: DEC e DEC Acumulado tem formulas diferentes. Em um unico mes os dois
-- coincidem — o erro so aparece ao consultar dois ou mais meses.

USE CATALOG IDENTIFIER(:catalogo);
USE SCHEMA gold;

CREATE OR REPLACE VIEW continuidade_metricas
WITH METRICS
LANGUAGE YAML
AS $$
  version: 1.1
  source: continuidade_conjunto_mes
  comment: "Metricas de continuidade do fornecimento por conjunto e mes — DEC e FEC com definicao unica no sistema (RN-04)"
  dimensions:
    - name: Conjunto
      expr: nome_conjunto
      comment: "Nome do conjunto de distribuicao"
      synonyms: [regiao, area, zona, territorio]
    - name: Codigo do Conjunto
      expr: id_conjunto
    - name: Municipio
      expr: municipio
    - name: Mes
      expr: mes_apuracao
      format:
        type: date
        date_format: year_month_day
  measures:
    - name: DEC
      expr: "SUM(uc_horas_interrompidas) / NULLIF(SUM(total_ucs), 0)"
      comment: "Duracao Equivalente de Interrupcao por UC em horas no mes"
      synonyms: ["horas sem luz", "duracao media sem fornecimento", "tempo de interrupcao"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 2
    - name: FEC
      expr: "SUM(uc_interrupcoes) / NULLIF(SUM(total_ucs), 0)"
      comment: "Frequencia Equivalente de Interrupcao por UC no mes"
      synonyms: ["frequencia de interrupcao", "numero de interrupcoes", "vezes sem luz"]
      format:
        type: number
        decimal_places:
          type: exact
          places: 2
    - name: DEC Acumulado
      expr: "SUM(uc_horas_interrompidas) / NULLIF(SUM(total_ucs) / COUNT(DISTINCT mes_apuracao), 0)"
      comment: "DEC acumulado no periodo consultado — formula diferente do DEC mensal para evitar que o denominador se multiplique pelo numero de meses"
      format:
        type: number
        decimal_places:
          type: exact
          places: 2
    - name: Interrupcoes
      expr: SUM(qtd_interrupcoes)
      synonyms: [eventos, ocorrencias, falhas]
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Interrupcoes Climaticas
      expr: SUM(qtd_interrupcoes_climaticas)
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Proporcao Climatica
      expr: "SUM(qtd_interrupcoes_climaticas) / NULLIF(SUM(qtd_interrupcoes), 0)"
      comment: "Parcela das interrupcoes com causa climatica"
      format:
        type: percentage
        decimal_places:
          type: exact
          places: 1
    - name: Interrupcoes Programadas
      expr: SUM(qtd_interrupcoes_programadas)
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
    - name: Horas UC Interrompidas
      expr: SUM(uc_horas_interrompidas)
      comment: "Numerador do DEC — soma aditiva de duracao_horas vezes ucs_afetadas"
      format:
        type: number
        decimal_places:
          type: exact
          places: 1
    - name: Maior Interrupcao
      expr: MAX(maior_duracao_horas)
      comment: "Maior evento do periodo em horas"
      format:
        type: number
        decimal_places:
          type: exact
          places: 2
    - name: Total de UCs
      expr: "SUM(total_ucs) / COUNT(DISTINCT mes_apuracao)"
      comment: "Total de UCs do conjunto — dividido pelo numero de meses para nao multiplicar ao agregar periodos"
      format:
        type: number
        decimal_places:
          type: exact
          places: 0
$$

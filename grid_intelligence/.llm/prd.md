# PRD — Grid Intelligence

Plataforma de dados e IA da **Luz do Vale Distribuidora S.A.**, construída no Databricks.

## Domínio

Uma distribuidora de energia elétrica opera sob regulação da ANEEL e enfrenta três dores
mensuráveis em dinheiro:

1. **Continuidade do fornecimento** — interrupções além do limite regulatório geram
   compensação financeira automática ao consumidor (R$ 1,1 bilhão pagos em 2024).
2. **Perdas não técnicas (PNT)** — energia distribuída e não faturada (furto, fraude,
   erro de medição). ~R$ 11,5 bilhões em 2025, dos quais ~R$ 7,9 bilhões repassados
   à tarifa.
3. **Atendimento ao cliente** — transcrições de ligações não analisadas que contêm
   avisos antecipados de reclamações na ouvidoria.

## Glossário

| Termo | Definição |
|---|---|
| **UC — Unidade Consumidora** | O ponto de entrega de energia. Não é sinônimo de cliente: um cliente pode ter várias UCs |
| **Conjunto** | Subdivisão geográfica da área de concessão. Unidade de agregação do regulador |
| **DEC** | Duração Equivalente de Interrupção por UC — tempo médio, em horas, sem fornecimento |
| **FEC** | Frequência Equivalente de Interrupção por UC — número médio de interrupções |
| **PNT** | Perdas Não Técnicas |
| **Prioridade de inspeção** | Classificação de quanto uma UC merece visita técnica (alta, média, baixa) |

## Regras de Negócio

| Regra | Descrição |
|---|---|
| **RN-01** | Só interrupções com 3 minutos ou mais entram na apuração de DEC e FEC. A regra vive na camada de transformação, nunca no relatório. |
| **RN-04** | DEC e FEC têm uma única definição no sistema, consumida por dashboard, agente e relatório. |
| **RN-06** | Uma UC é candidata a inspeção quando o consumo cai em dois eixos simultâneos: contra o próprio baseline e enquanto a vizinhança permanece estável. |
| **RN-07** | A saída da detecção é prioridade de inspeção (alta, média, baixa). Nunca um rótulo de fraude, furto ou culpa. Nenhuma coluna, variável ou comentário pode usar "fraude", "furto" ou "culpado" como rótulo de saída. |
| **RN-09** | Dado pessoal em transcrição é mascarado antes de qualquer análise de conteúdo. |
| **RN-10** | O texto original identificado é preservado com acesso restrito. Duas proteções coexistem: uma na leitura, outra na análise. |
| **RN-11** | A camada de ingestão não filtra, não corrige e não aplica regra de negócio. Leitura inválida de medidor é um fato sobre o medidor. |
| **RN-12** | Todo registro ingerido carrega origem e momento de ingestão. |
| **RN-13** | O agente conversacional acessa apenas a camada de negócio (gold). |
| **RN-14** | As entidades da camada gold carregam descrição em linguagem de negócio. Bronze e silver não precisam: são passagem. |

## Modelo de Informação

### Bases de dados (sintéticas)

| Base | Grão | Volume |
|---|---|---|
| `unidades_consumidoras` | uma por ponto de entrega | 4.000 UCs |
| `interrupcoes` | uma por evento de rede | 1.383 eventos |
| `consumo_diario` | uma por UC por dia | ~5,85 milhões de registros (4 anos) |
| `chamados` | uma por ligação, com transcrição | 2.801 chamados |

4 anos de histórico, crescimento de 30% ao ano na carga, sazonalidade de verão no
atendimento (dezembro–março recebem quase o dobro de ligações).

### Arquitetura de camadas (Medallion)

| Camada | Schema | Responsabilidade |
|---|---|---|
| **Raw** | `raw` | Volume `landing` — arquivos Parquet originais, sem toque |
| **Bronze** | `bronze` | Ingestão fiel: lê o volume, adiciona metadados, sem regra de negócio (RN-11, RN-12) |
| **Silver** | `silver` | Transformações: regra dos 3 min (RN-01), dedup, baseline, anonimização (RN-09) |
| **Gold** | `gold` | Entidades de negócio com descrição (RN-14), acessadas pelo agente (RN-13) |

Isolamento entre ambientes feito por catálogo:

| Ambiente | Catálogo |
|---|---|
| `dev` | `grid_dev` |
| `prod` | `grid_intelligence` |

### Entregas de negócio previstas

1. **Monitoramento de continuidade** — DEC e FEC por conjunto, com histórico e alerta
   regulatório (RN-01, RN-04).
2. **Detecção de anomalias de consumo** — prioridade de inspeção por UC (RN-06, RN-07).
3. **Análise de chamados** — sentimento, categorização e detecção de padrões nas
   transcrições (RN-09, RN-10).
4. **Agente conversacional** — copiloto em português que responde perguntas sobre a
   gold (RN-13, RN-14).

# Grid Intelligence

Plataforma de dados e IA da **Luz do Vale Distribuidora S.A.**, construída no Databricks.

Consulte `.llm/prd.md` para o contexto de negócio completo, glossário e regras de negócio.

## Estrutura

```
databricks.yml              # Bundle principal + targets dev/prod
resources/
  grid_schemas.yml          # Schemas raw/bronze/silver/gold e volume landing
.llm/
  prd.md                    # Documento de requisitos do produto
landing/                    # Arquivos Parquet originais (upload para o volume)
  chamados/
  consumo_diario/
  interrupcoes/
  unidades_consumidoras/
```

## Ambientes

| Ambiente | Catálogo       | Target         |
|----------|---------------|----------------|
| `dev`    | `grid_dev`    | `-t dev`       |
| `prod`   | `grid_intelligence` | `-t prod` |

O catálogo isola os ambientes — os schemas `raw`, `bronze`, `silver` e `gold` têm o
mesmo nome nos dois lados, para que o mesmo SQL rode em qualquer ambiente sem alteração.

## Setup inicial

### 1. Criar catálogos (SQL — feito uma vez)

```bash
databricks experimental aitools tools query --profile grid_intelligence \
  "CREATE CATALOG IF NOT EXISTS grid_dev COMMENT 'Catalogo de desenvolvimento da Grid Intelligence'"

databricks experimental aitools tools query --profile grid_intelligence \
  "CREATE CATALOG IF NOT EXISTS grid_intelligence COMMENT 'Catalogo de producao da Grid Intelligence'"
```

### 2. Conceder permissões

```bash
databricks grants update CATALOG grid_dev \
  --json '{"changes":[{"principal":"SEU-EMAIL","add":["ALL_PRIVILEGES"]}]}' \
  --profile grid_intelligence

databricks grants update CATALOG grid_intelligence \
  --json '{"changes":[{"principal":"SEU-EMAIL","add":["ALL_PRIVILEGES"]}]}' \
  --profile grid_intelligence
```

### 3. Deploy

```bash
databricks bundle validate --profile grid_intelligence
databricks bundle deploy -t dev --profile grid_intelligence
```

## Subir os dados (upload para o volume)

Após o deploy, os arquivos Parquet ficam em:

```
/Volumes/grid_dev/raw/landing/unidades_consumidoras/
/Volumes/grid_dev/raw/landing/interrupcoes/
/Volumes/grid_dev/raw/landing/consumo_diario/
/Volumes/grid_dev/raw/landing/chamados/
```

Para subir tudo de uma vez pelo terminal (executar da raiz do projeto):

```bash
databricks fs cp -r landing/unidades_consumidoras \
  dbfs:/Volumes/grid_dev/raw/landing/unidades_consumidoras \
  --overwrite --profile grid_intelligence

databricks fs cp -r landing/interrupcoes \
  dbfs:/Volumes/grid_dev/raw/landing/interrupcoes \
  --overwrite --profile grid_intelligence

databricks fs cp -r landing/consumo_diario \
  dbfs:/Volumes/grid_dev/raw/landing/consumo_diario \
  --overwrite --profile grid_intelligence

databricks fs cp -r landing/chamados \
  dbfs:/Volumes/grid_dev/raw/landing/chamados \
  --overwrite --profile grid_intelligence
```

Ou subir todas de uma vez (sobe as quatro subpastas):

```bash
databricks fs cp -r landing dbfs:/Volumes/grid_dev/raw/landing \
  --overwrite --profile grid_intelligence
```

> O prefixo `dbfs:` é obrigatório mesmo para Volume do Unity Catalog.

## ⚠️ DESTRUTIVO — Recriar catálogo do zero

**Este comando remove schemas, tabelas, volumes e os arquivos dentro deles. Não há
confirmação. Sempre confirme com o time antes de executar.**

```bash
databricks experimental aitools tools query --profile grid_intelligence \
  "DROP CATALOG IF EXISTS grid_dev CASCADE"
```

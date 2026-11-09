-- A streaming table bronze.chamados e recriada a cada full refresh do pipeline,
-- e a column mask e removida junto com a tabela. Esta task re-aplica a mascara
-- apos cada execucao do job, garantindo que a protecao permaneca ativa (RN-10).

USE CATALOG IDENTIFIER(:catalogo);
USE SCHEMA bronze;

CREATE OR REPLACE FUNCTION mascara_dado_pessoal(val STRING)
RETURNS STRING
LANGUAGE SQL
RETURN IF(is_account_group_member('atendimento'), val, '[RESTRITO]');

ALTER TABLE chamados
  ALTER COLUMN nome_solicitante    SET MASK mascara_dado_pessoal;

ALTER TABLE chamados
  ALTER COLUMN telefone_solicitante SET MASK mascara_dado_pessoal;

ALTER TABLE chamados
  ALTER COLUMN transcricao         SET MASK mascara_dado_pessoal;

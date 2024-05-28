-- SQL PROJECT (Data Cleaning)

-- A base de dados está disponível em:
-- https://www.kaggle.com/datasets/swaptr/layoffs-2022


-- No desenvolvimento do projeto a seguinte metodologia será adotada:

-- 0. Por boa prática, a fim de preservar a base dedados original, todas as alterações serão realizadas através de uma tabela temporária que poderá no futuro, caso necessário, consolidada.
-- 1. Verificar se a base possui linhas duplicadas e eliminar as mesmas.
-- 2. Padronizar os dados.
-- 3. Remover as linhas e colunas que não são relevantes para a análise proposta.

-- ____________________________________________________________________________________________________________________________________________________________________________
-- Primeiro vamos criar a tabela temporária que utilizaremos ao longo do projeto

-- Criando a tabela equivalente a nossa base de dados original
CREATE TEMPORARY TABLE `layoffs_staging` (
  `company` text,
  `location` text,
  `industry` text,
  `total_laid_off` int DEFAULT NULL,
  `percentage_laid_off` text,
  `date` text,
  `stage` text,
  `country` text,
  `funds_raised_millions` int DEFAULT NULL,
  `duplicate_count` INT -- Aqui estamos criando uma coluna extra, a mesma será utilizada para a identificação e remoção de duplicatas.
  
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Ao verificar, podemos observar que possuímos uma tabela vazia
SELECT *
FROM layoffs_staging; 

-- Agora vamos inserir as informações da nossa tabela base na nova tabela
INSERT INTO layoffs_staging
SELECT * 
, ROW_NUMBER() OVER (partition by company -- Aqui introduzimos a coluna responsável por identificar as linhas únicas
						, location
                        , industry
                        , total_laid_off
                        , percentage_laid_off
                        , `date`
                        , stage
                        , country
                        , funds_raised_millions
				) AS duplicate_count
FROM layoffs_db;

-- Aqui as linhas que possuem número superior a 1 são as nossas duplicadas, vamos verificar
SELECT *
FROM layoffs_staging
WHERE duplicate_count > 1;

-- Agora é só remover as duplicadas
DELETE FROM layoffs_staging
WHERE duplicate_count > 1;

-- _______________________________________________________________________________________________________________________________________________________________________
-- Agora vamos padronizar os dados!
-- Para cada coluna iremos remover os espaços através da função TRIM().
-- Padronizar as vacâncias. A fim de faciliar as queries futuras iremos transformar as strings vazias '' em NULL.
-- Quando possível os vazios serão repopulados (a depender de cada caso).
-- Eventualmente se algo pontual surgir será corrigido aqui mesmo.
-- Vamos começar!



-- Coluna 'company':

-- Primeiro o TRIM
UPDATE layoffs_staging
SET company = TRIM(company);

-- Checar se há strings vazias ou NULL
SELECT company
FROM layoffs_staging
WHERE company IS NULL OR company = ''; 
-- Tudo OK!

-- Scan rápido para ver se há algo mais que eu precise fazer...
SELECT DISTINCT company
FROM layoffs_staging
ORDER BY company; 
-- Parece tudo OK!



-- Coluna 'location':

-- Primeiro o TRIM
UPDATE layoffs_staging
SET location = TRIM(location);

-- Checar se há strings vazias ou NULL
SELECT location
FROM layoffs_staging
WHERE location IS NULL OR location = ''; 
-- Tudo OK!

-- Scan rápido pra ver se há algo mais que eu precise fazer...
SELECT DISTINCT location
FROM layoffs_staging
ORDER BY location; 
-- Há algumas cidades com os caracteres bugados por conta do uso de acentuação.
-- É possível corrigir usando a função REPLACE(). Entretanto, na minha experiência, por padrão todas as bases de dados nas quais eu já trabalhei em uma RDBMS o DBA já limitavam o uso de acentuação.
-- Isso é mais comum quando a fonte de dados é oriunda ou de um arquivo CSV ou de um FORMS... Onde esses dados são tratados já no aplicativo de criação de dashboards, como o Power BI.
-- Por essa razão, iremos nos abster de realizar essa etapa.


-- Coluna 'industry'

-- Primeiro o TRIM()
UPDATE layoffs_staging
SET industry = TRIM(industry);

-- Checar se há strings vazias ou NULL
SELECT industry
FROM layoffs_staging
WHERE industry IS NULL OR industry = ''; 
-- Há um NULL e outros com strings vazias. 

-- Vamos primeiro colocar todos como NULL.
UPDATE layoffs_staging
SET industry = NULL
WHERE industry = '';

-- Agora vamos analisar as linhas que possuem NULL na coluna industry.
SELECT *
FROM layoffs_staging
WHERE industry IS NULL;

-- Podemos observar que há empresas como Airbnb, Bally's Interactive, Carvana e Juul.
-- Notei que há outras entradas nessa base onde a empresa é a mesma e na coluna industry o campo foi preenchido.
-- Como no exemplo a seguir:
SELECT *
FROM layoffs_staging
WHERE company = 'Airbnb'; 
-- Observe que a coluna industry em outra entrada foi preenchida como Travel
-- Nesse sentido iremos escrever um código capaz de verificar se para os demais valores em NULL há outras entradas da mesma empresa onde o campo foi preenchido
-- Caso haja, iremos repopular esses NULL com os valores das outras entradas equivalentes
-- Como não é possível referenciar a mesma tabela temporária em um SELF JOIN irei criar uma nova tabela temporária apenas para essa parte do código.

-- Criando a tabela temporária
CREATE TEMPORARY TABLE t2 LIKE layoffs_staging;

-- Inserindo os dados
INSERT INTO t2
SELECT *
FROM layoffs_staging;

-- Essa querie identifica se há outra entrada da mesma empresa onde o campo industry não esteja nulo, iremos preencher o campo nulo com esse outro valor equivalente
UPDATE layoffs_staging t1
JOIN t2
ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
AND t2.industry IS NOT NULL;

-- Vamos checar como ficou
SELECT *
FROM layoffs_staging
WHERE industry IS NULL OR industry = ''; 
-- Todas as vacâncias foram preenchidas corretamente!
-- A única que permanceu sem preencher foi a companhia Bally's uma vez que ela não havia outra entrada para comparação.

-- Vamos agora dar uma scaneada final na coluna industry
SELECT DISTINCT industry
FROM layoffs_staging; 
-- A indústria 'Crypto' é citada de 3 maneiras diferentes:
-- Crypto, CryptoCurrency e Crypto Currency

-- Vamos padronizar e deixar tudo como 'Crypto'
UPDATE layoffs_staging
SET industry = 'Crypto'
WHERE industry IN ('Crypto Currency', 'CryptoCurrency'); 
-- Finalizado!


-- total_laid_off

-- Vamos verificar se há NULL ou empty strings
SELECT DISTINCT total_laid_off
FROM layoffs_staging
WHERE total_laid_off IS NULL OR total_laid_off = ''; 
-- Somente NULL, não precisamos converter nada.


-- percentage_laid_off

-- Vamos verificar se há NULL ou empty strings
SELECT DISTINCT percentage_laid_off
FROM layoffs_staging
WHERE percentage_laid_off IS NULL OR percentage_laid_off = ''; 
-- Somente NULL, não precisamos converter nada.


-- Date

-- Vamos formatar a coluna para data
UPDATE layoffs_staging
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

-- E converter o tipo de dado para data
ALTER TABLE layoffs_staging
MODIFY COLUMN `date` DATE;


-- Country

-- Primeiro o TRIM()
UPDATE layoffs_staging
SET country = TRIM(country);

-- Verificar se há empty or null 
SELECT DISTINCT country
FROM layoffs_staging
WHERE country IS NULL OR country = ''; 
-- Tudo OK!

-- Scaneada final:
SELECT DISTINCT country
FROM layoffs_staging
ORDER BY country;
-- Parece que o único erro esta em United States, o mesmo foi escrito de duas maneiras:
-- 'United States' e 'United States.', logo vamos retirar esse ponto final.

UPDATE layoffs_staging
SET country = TRIM(TRAILING '.' FROM country); 
-- Corrigido!



-- _______________________________________________________________________________________________________________________________________________________________________
-- Remover colunas desnecessárias

-- Para esse projeto iremos considerar como colunas desnecessárias as seguintes colunas:
-- stage, funds_raised_millions e duplicate_count. Isso foi apenas uma decisão arbitrária.

-- Logo, vamos removê-las
ALTER TABLE layoffs_staging
DROP COLUMN duplicate_count;

ALTER TABLE layoffs_staging
DROP COLUMN stage;

ALTER TABLE layoffs_staging
DROP COLUMN funds_raised_millions;

-- Por fim as linhas onde tanto total_laid_off quanto percentage_laid_off possuem valores nulos serão removidas.
-- Iremos considerar que essas são as únicas 2 informações relevantes e quem sem elas não é possível extrair nada.

-- Logo vamos removê-las
DELETE FROM layoffs_staging
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

-- Resultado Final:
select company
	, location
	, industry
    , total_laid_off AS laid_off
    , percentage_laid_off AS p_laid_off
    , `date`
    , country
from layoffs_staging
ORDER BY laid_off DESC, p_laid_off DESC;

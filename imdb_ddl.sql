-- ============================================================
--  IMDb MySQL DDL
--  Gerado para MySQL 8.0+
--  Charset: utf8mb4 / Collation: utf8mb4_unicode_ci
-- ============================================================

CREATE DATABASE IF NOT EXISTS imdb
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE imdb;

-- ------------------------------------------------------------
-- name_basics
-- Pessoas: atores, diretores, escritores, etc.
-- Fonte: name.basics.tsv.gz
-- ------------------------------------------------------------
CREATE TABLE name_basics (
  nconst              VARCHAR(12)   NOT NULL              COMMENT 'Identificador único da pessoa (ex: nm0000001)',
  primaryName         VARCHAR(255)  NOT NULL              COMMENT 'Nome pelo qual a pessoa é mais conhecida',
  birthYear           SMALLINT      NULL                  COMMENT 'Ano de nascimento (SMALLINT suporta anos históricos anteriores a 1901)',
  deathYear           SMALLINT      NULL                  COMMENT 'Ano de falecimento; NULL se ainda vivo',
  primaryProfession   VARCHAR(255)  NULL                  COMMENT 'Até 3 profissões separadas por vírgula',
  knownForTitles      VARCHAR(255)  NULL                  COMMENT 'tconsts separados por vírgula — títulos pelos quais é conhecido',
  PRIMARY KEY (nconst),
  INDEX idx_name (primaryName)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;


-- ------------------------------------------------------------
-- title_basics
-- Catálogo principal de títulos
-- Fonte: title.basics.tsv.gz
-- ------------------------------------------------------------
CREATE TABLE title_basics (
  tconst              VARCHAR(12)       NOT NULL          COMMENT 'Identificador único do título (ex: tt0000001)',
  titleType           VARCHAR(50)       NOT NULL          COMMENT 'Tipo: movie, short, tvseries, tvepisode, video, tvMovie, etc.',
  primaryTitle        VARCHAR(512)      NOT NULL          COMMENT 'Título principal / usado em materiais de divulgação',
  originalTitle       VARCHAR(512)      NOT NULL          COMMENT 'Título original no idioma de produção',
  isAdult             TINYINT(1)        NOT NULL DEFAULT 0 COMMENT '0 = não adulto; 1 = adulto',
  startYear           SMALLINT UNSIGNED NULL              COMMENT 'Ano de lançamento; para séries, ano de estreia',
  endYear             SMALLINT UNSIGNED NULL              COMMENT 'Ano de encerramento (somente séries de TV)',
  runtimeMinutes      SMALLINT UNSIGNED NULL              COMMENT 'Duração principal em minutos',
  genres              VARCHAR(255)      NULL              COMMENT 'Até 3 gêneros separados por vírgula',
  PRIMARY KEY (tconst),
  INDEX idx_titleType  (titleType),
  INDEX idx_startYear  (startYear),
  INDEX idx_isAdult    (isAdult)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;


-- ------------------------------------------------------------
-- title_akas
-- Títulos alternativos / localizados por região e idioma
-- Fonte: title.akas.tsv.gz
-- ------------------------------------------------------------
CREATE TABLE title_akas (
  titleId             VARCHAR(12)       NOT NULL          COMMENT 'FK para title_basics.tconst',
  ordering            SMALLINT UNSIGNED NOT NULL          COMMENT 'Número de ordem para identificar linhas de um mesmo titleId',
  title               VARCHAR(512)      NOT NULL          COMMENT 'Título localizado',
  region              VARCHAR(10)       NULL              COMMENT 'Região desta versão do título (ex: BR, US, PT)',
  language            VARCHAR(10)       NULL              COMMENT 'Idioma do título',
  types               VARCHAR(255)      NULL              COMMENT 'Atributos: alternative, dvd, festival, tv, video, working, original, imdbDisplay',
  attributes          VARCHAR(255)      NULL              COMMENT 'Termos adicionais para descrever o título alternativo',
  isOriginalTitle     TINYINT(1)        NULL              COMMENT '1 = título original; 0 = não é o título original',
  PRIMARY KEY (titleId, ordering),
  CONSTRAINT fk_akas_title
    FOREIGN KEY (titleId) REFERENCES title_basics (tconst)
    ON DELETE CASCADE ON UPDATE CASCADE,
  INDEX idx_akas_region   (region),
  INDEX idx_akas_language (language)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;


-- ------------------------------------------------------------
-- title_crew
-- Diretores e roteiristas de cada título
-- Fonte: title.crew.tsv.gz
-- ------------------------------------------------------------
CREATE TABLE title_crew (
  tconst              VARCHAR(12)   NOT NULL              COMMENT 'FK para title_basics.tconst',
  directors           TEXT          NULL                  COMMENT 'nconsts separados por vírgula',
  writers             TEXT          NULL                  COMMENT 'nconsts separados por vírgula',
  PRIMARY KEY (tconst),
  CONSTRAINT fk_crew_title
    FOREIGN KEY (tconst) REFERENCES title_basics (tconst)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;


-- ------------------------------------------------------------
-- title_episode
-- Episódios de séries de TV
-- Fonte: title.episode.tsv.gz
-- ------------------------------------------------------------
CREATE TABLE title_episode (
  tconst              VARCHAR(12)       NOT NULL          COMMENT 'tconst do episódio',
  parentTconst        VARCHAR(12)       NOT NULL          COMMENT 'tconst da série pai',
  seasonNumber        SMALLINT UNSIGNED NULL              COMMENT 'Número da temporada',
  episodeNumber       SMALLINT UNSIGNED NULL              COMMENT 'Número do episódio dentro da temporada',
  PRIMARY KEY (tconst),
  CONSTRAINT fk_episode_self
    FOREIGN KEY (tconst)        REFERENCES title_basics (tconst)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_episode_parent
    FOREIGN KEY (parentTconst)  REFERENCES title_basics (tconst)
    ON DELETE CASCADE ON UPDATE CASCADE,
  INDEX idx_episode_parent  (parentTconst),
  INDEX idx_episode_season  (parentTconst, seasonNumber, episodeNumber)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;


-- ------------------------------------------------------------
-- title_principals
-- Elenco e equipe principal de cada título
-- Fonte: title.principals.tsv.gz
-- ------------------------------------------------------------
CREATE TABLE title_principals (
  tconst              VARCHAR(12)       NOT NULL          COMMENT 'FK para title_basics.tconst',
  ordering            TINYINT UNSIGNED  NOT NULL          COMMENT 'Ordem de importância no título',
  nconst              VARCHAR(12)       NOT NULL          COMMENT 'FK para name_basics.nconst',
  category            VARCHAR(100)      NOT NULL          COMMENT 'Categoria do trabalho: actor, actress, director, producer, composer, etc.',
  job                 VARCHAR(255)      NULL              COMMENT 'Cargo específico quando aplicável',
  characters          VARCHAR(512)      NULL              COMMENT 'Nome(s) do(s) personagem(ns) interpretado(s)',
  PRIMARY KEY (tconst, ordering),
  CONSTRAINT fk_princ_title
    FOREIGN KEY (tconst)  REFERENCES title_basics  (tconst)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_princ_name
    FOREIGN KEY (nconst)  REFERENCES name_basics   (nconst)
    ON DELETE CASCADE ON UPDATE CASCADE,
  INDEX idx_princ_nconst    (nconst),
  INDEX idx_princ_category  (category)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;


-- ------------------------------------------------------------
-- title_ratings
-- Avaliações e votos dos usuários do IMDb
-- Fonte: title.ratings.tsv.gz
-- ------------------------------------------------------------
CREATE TABLE title_ratings (
  tconst              VARCHAR(12)       NOT NULL          COMMENT 'FK para title_basics.tconst',
  averageRating       DECIMAL(3,1)      NOT NULL          COMMENT 'Média ponderada de todas as avaliações individuais (0.0 a 10.0)',
  numVotes            INT UNSIGNED      NOT NULL          COMMENT 'Total de votos recebidos',
  PRIMARY KEY (tconst),
  CONSTRAINT fk_ratings_title
    FOREIGN KEY (tconst) REFERENCES title_basics (tconst)
    ON DELETE CASCADE ON UPDATE CASCADE,
  INDEX idx_ratings_avg   (averageRating),
  INDEX idx_ratings_votes (numVotes)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;


-- ============================================================
--  SCRIPTS DE CARGA (LOAD DATA)
--  Ajuste os caminhos conforme o seu ambiente.
--  Requer: LOCAL_INFILE=ON no servidor e no cliente.
--    SET GLOBAL local_infile = 1;
-- ============================================================

/*

-- 1. name_basics
LOAD DATA LOCAL INFILE '/caminho/name.basics.tsv'
INTO TABLE name_basics
FIELDS TERMINATED BY '\t'
LINES  TERMINATED BY '\n'
IGNORE 1 ROWS
(nconst, primaryName, @birthYear, @deathYear, @prof, @titles)
SET
  birthYear           = NULLIF(@birthYear, '\\N'),
  deathYear           = NULLIF(@deathYear, '\\N'),
  primaryProfession   = NULLIF(@prof,      '\\N'),
  knownForTitles      = NULLIF(@titles,    '\\N');

-- 2. title_basics
LOAD DATA LOCAL INFILE '/caminho/title.basics.tsv'
INTO TABLE title_basics
FIELDS TERMINATED BY '\t'
LINES  TERMINATED BY '\n'
IGNORE 1 ROWS
(tconst, titleType, primaryTitle, originalTitle, isAdult,
 @startYear, @endYear, @runtime, @genres)
SET
  startYear           = NULLIF(@startYear, '\\N'),
  endYear             = NULLIF(@endYear,   '\\N'),
  runtimeMinutes      = NULLIF(@runtime,   '\\N'),
  genres              = NULLIF(@genres,    '\\N');

-- 3. title_akas
LOAD DATA LOCAL INFILE '/caminho/title.akas.tsv'
INTO TABLE title_akas
FIELDS TERMINATED BY '\t'
LINES  TERMINATED BY '\n'
IGNORE 1 ROWS
(titleId, ordering, title, @region, @language, @types, @attributes, @isOrig)
SET
  region              = NULLIF(@region,     '\\N'),
  language            = NULLIF(@language,   '\\N'),
  types               = NULLIF(@types,      '\\N'),
  attributes          = NULLIF(@attributes, '\\N'),
  isOriginalTitle     = NULLIF(@isOrig,     '\\N');

-- 4. title_crew
LOAD DATA LOCAL INFILE '/caminho/title.crew.tsv'
INTO TABLE title_crew
FIELDS TERMINATED BY '\t'
LINES  TERMINATED BY '\n'
IGNORE 1 ROWS
(tconst, @directors, @writers)
SET
  directors           = NULLIF(@directors, '\\N'),
  writers             = NULLIF(@writers,   '\\N');

-- 5. title_episode
LOAD DATA LOCAL INFILE '/caminho/title.episode.tsv'
INTO TABLE title_episode
FIELDS TERMINATED BY '\t'
LINES  TERMINATED BY '\n'
IGNORE 1 ROWS
(tconst, parentTconst, @season, @episode)
SET
  seasonNumber        = NULLIF(@season,  '\\N'),
  episodeNumber       = NULLIF(@episode, '\\N');

-- 6. title_principals
LOAD DATA LOCAL INFILE '/caminho/title.principals.tsv'
INTO TABLE title_principals
FIELDS TERMINATED BY '\t'
LINES  TERMINATED BY '\n'
IGNORE 1 ROWS
(tconst, ordering, nconst, category, @job, @characters)
SET
  job                 = NULLIF(@job,        '\\N'),
  characters          = NULLIF(@characters, '\\N');

-- 7. title_ratings
LOAD DATA LOCAL INFILE '/caminho/title.ratings.tsv'
INTO TABLE title_ratings
FIELDS TERMINATED BY '\t'
LINES  TERMINATED BY '\n'
IGNORE 1 ROWS
(tconst, averageRating, numVotes);

*/

-- ============================================================
--  IMDb PostgreSQL DDL
--  Testado em PostgreSQL 14+
-- ============================================================

-- Cria e seleciona o schema (equivalente ao USE do MySQL)
CREATE SCHEMA IF NOT EXISTS imdb;
SET search_path TO imdb;


-- ------------------------------------------------------------
-- name_basics
-- ------------------------------------------------------------
CREATE TABLE name_basics (
  nconst              VARCHAR(12)   NOT NULL,
  "primaryName"       VARCHAR(255)  NOT NULL,
  "birthYear"         SMALLINT,
  "deathYear"         SMALLINT,
  "primaryProfession" VARCHAR(255),
  "knownForTitles"    VARCHAR(255),
  CONSTRAINT pk_name_basics PRIMARY KEY (nconst)
);

CREATE INDEX idx_name_primaryname ON name_basics ("primaryName");


-- ------------------------------------------------------------
-- title_basics
-- ------------------------------------------------------------
CREATE TABLE title_basics (
  tconst              VARCHAR(12)   NOT NULL,
  "titleType"         VARCHAR(50)   NOT NULL,
  "primaryTitle"      VARCHAR(512)  NOT NULL,
  "originalTitle"     VARCHAR(512)  NOT NULL,
  "isAdult"           BOOLEAN       NOT NULL DEFAULT FALSE,
  "startYear"         SMALLINT,
  "endYear"           SMALLINT,
  "runtimeMinutes"    SMALLINT      CHECK ("runtimeMinutes" > 0),
  genres              VARCHAR(255),
  CONSTRAINT pk_title_basics PRIMARY KEY (tconst)
);

CREATE INDEX idx_title_titletype  ON title_basics ("titleType");
CREATE INDEX idx_title_startyear  ON title_basics ("startYear");
CREATE INDEX idx_title_isadult    ON title_basics ("isAdult");


-- ------------------------------------------------------------
-- title_akas
-- ------------------------------------------------------------
CREATE TABLE title_akas (
  "titleId"           VARCHAR(12)   NOT NULL,
  ordering            SMALLINT      NOT NULL,
  title               VARCHAR(512)  NOT NULL,
  region              VARCHAR(10),
  "language"          VARCHAR(10),
  types               VARCHAR(255),
  attributes          VARCHAR(255),
  "isOriginalTitle"   BOOLEAN,
  CONSTRAINT pk_title_akas PRIMARY KEY ("titleId", ordering),
  CONSTRAINT fk_akas_title FOREIGN KEY ("titleId")
    REFERENCES title_basics (tconst)
    ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX idx_akas_region   ON title_akas (region);
CREATE INDEX idx_akas_language ON title_akas ("language");


-- ------------------------------------------------------------
-- title_crew
-- ------------------------------------------------------------
CREATE TABLE title_crew (
  tconst              VARCHAR(12)   NOT NULL,
  directors           TEXT,
  writers             TEXT,
  CONSTRAINT pk_title_crew PRIMARY KEY (tconst),
  CONSTRAINT fk_crew_title FOREIGN KEY (tconst)
    REFERENCES title_basics (tconst)
    ON DELETE CASCADE ON UPDATE CASCADE
);


-- ------------------------------------------------------------
-- title_episode
-- ------------------------------------------------------------
CREATE TABLE title_episode (
  tconst              VARCHAR(12)   NOT NULL,
  "parentTconst"      VARCHAR(12)   NOT NULL,
  "seasonNumber"      SMALLINT      CHECK ("seasonNumber" > 0),
  "episodeNumber"     SMALLINT      CHECK ("episodeNumber" > 0),
  CONSTRAINT pk_title_episode PRIMARY KEY (tconst),
  CONSTRAINT fk_episode_self FOREIGN KEY (tconst)
    REFERENCES title_basics (tconst)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_episode_parent FOREIGN KEY ("parentTconst")
    REFERENCES title_basics (tconst)
    ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX idx_episode_parent ON title_episode ("parentTconst");
CREATE INDEX idx_episode_season ON title_episode ("parentTconst", "seasonNumber", "episodeNumber");


-- ------------------------------------------------------------
-- title_principals
-- ------------------------------------------------------------
CREATE TABLE title_principals (
  tconst              VARCHAR(12)   NOT NULL,
  ordering            SMALLINT      NOT NULL,
  nconst              VARCHAR(12)   NOT NULL,
  category            VARCHAR(100)  NOT NULL,
  job                 VARCHAR(255),
  characters          VARCHAR(512),
  CONSTRAINT pk_title_principals PRIMARY KEY (tconst, ordering),
  CONSTRAINT fk_princ_title FOREIGN KEY (tconst)
    REFERENCES title_basics (tconst)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_princ_name FOREIGN KEY (nconst)
    REFERENCES name_basics (nconst)
    ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX idx_princ_nconst   ON title_principals (nconst);
CREATE INDEX idx_princ_category ON title_principals (category);


-- ------------------------------------------------------------
-- title_ratings
-- ------------------------------------------------------------
CREATE TABLE title_ratings (
  tconst              VARCHAR(12)     NOT NULL,
  "averageRating"     NUMERIC(3,1)    NOT NULL CHECK ("averageRating" BETWEEN 0 AND 10),
  "numVotes"          INTEGER         NOT NULL CHECK ("numVotes" >= 0),
  CONSTRAINT pk_title_ratings PRIMARY KEY (tconst),
  CONSTRAINT fk_ratings_title FOREIGN KEY (tconst)
    REFERENCES title_basics (tconst)
    ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX idx_ratings_avg   ON title_ratings ("averageRating");
CREATE INDEX idx_ratings_votes ON title_ratings ("numVotes");


-- ============================================================
--  CARGA DE DADOS via COPY
--  Equivalente ao LOAD DATA LOCAL INFILE do MySQL.
--  O \N dos ficheiros IMDb precisa ser tratado como NULL.
--  Requer acesso de superuser ou pg_read_server_files.
-- ============================================================

/*

-- Desativa FKs temporariamente para acelerar a carga
SET session_replication_role = replica;

-- 1. name_basics
COPY imdb.name_basics (nconst, "primaryName", "birthYear", "deathYear", "primaryProfession", "knownForTitles")
FROM 'C:/Users/andre/Downloads/imdb/name.basics.tsv'
WITH (FORMAT text, DELIMITER E'\t', NULL '\N', HEADER true, ENCODING 'UTF8');

-- 2. title_basics
COPY imdb.title_basics (tconst, "titleType", "primaryTitle", "originalTitle", "isAdult", "startYear", "endYear", "runtimeMinutes", genres)
FROM 'C:/Users/andre/Downloads/imdb/title.basics.tsv'
WITH (FORMAT text, DELIMITER E'\t', NULL '\N', HEADER true, ENCODING 'UTF8');

-- 3. title_akas
COPY imdb.title_akas ("titleId", ordering, title, region, "language", types, attributes, "isOriginalTitle")
FROM 'C:/Users/andre/Downloads/imdb/title.akas.tsv'
WITH (FORMAT text, DELIMITER E'\t', NULL '\N', HEADER true, ENCODING 'UTF8');

-- 4. title_crew
COPY imdb.title_crew (tconst, directors, writers)
FROM 'C:/Users/andre/Downloads/imdb/title.crew.tsv'
WITH (FORMAT text, DELIMITER E'\t', NULL '\N', HEADER true, ENCODING 'UTF8');

-- 5. title_episode
COPY imdb.title_episode (tconst, "parentTconst", "seasonNumber", "episodeNumber")
FROM 'C:/Users/andre/Downloads/imdb/title.episode.tsv'
WITH (FORMAT text, DELIMITER E'\t', NULL '\N', HEADER true, ENCODING 'UTF8');

-- 6. title_principals
COPY imdb.title_principals (tconst, ordering, nconst, category, job, characters)
FROM 'C:/Users/andre/Downloads/imdb/title.principals.tsv'
WITH (FORMAT text, DELIMITER E'\t', NULL '\N', HEADER true, ENCODING 'UTF8');

-- 7. title_ratings
COPY imdb.title_ratings (tconst, "averageRating", "numVotes")
FROM 'C:/Users/andre/Downloads/imdb/title.ratings.tsv'
WITH (FORMAT text, DELIMITER E'\t', NULL '\N', HEADER true, ENCODING 'UTF8');

-- Reativa FKs
SET session_replication_role = DEFAULT;

*/

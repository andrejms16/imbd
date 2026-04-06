# IMDb TV Series Market Analysis: Data Warehouse Lab Report

**Course:** Master in Data Science and Engineering (MECD)  
**Subject:** Data Warehouses  
**Professor:** Gabriel David  
**Authors:** Davi Santos, André de Oliveira, Daniel Martinez  

---

## 1. Subject Description and Goals

The core of this project is the design and implementation of a dimensional model based on the IMDb dataset to analyze the global TV Series market. While the source data is vast, covering everything from cinema to documentaries, our objective is to isolate and study **TV Series** released from the year **2000 onwards**, excluding adult content. This specific subset allows for a manageable yet "Big Data" scale analysis of modern television trends.

The primary goals are to evaluate series industry performance through their caracteristics, also considering their ratings and viewer engagement, and finally to map the professional networks of the cast and crew (participations). By moving from an operational, normalized structure to a de-normalized star schema, we aim to facilitate complex analytical queries such as identifying "quality fatigue" across seasons or detecting high-impact collaborations between industry professionals.

## 2. Planning: Dimensional Bus Matrix, Dimensions and Facts Dictionary

Our planning phase was guided by the need for conformed dimensions, ensuring that entities like "Series" or "Time" remain consistent across different analysis stars.

### Dimensional Bus Matrix
The following matrix illustrates how our facts interact with shared dimensions:

| Data Mart | Fact / Star | dim_time | dim_series | dim_season | dim_episode | dim_genre | bridge_genres | dim_person | dim_profession | dim_role |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **TV Series** | fact_series_performance | X | X | X | | X | X | | | |
| **TV Series** | fact_ratings | | | | X | | X | X | X | |
| **TV Series** | participations_pers | | | | | | X | X | X | X |

### Dimensions Dictionary (Summary)
 
| Dimension | SCD | Grain | Key Attributes | Source |
|:---|:---:|:---|:---|:---|
| `dim_time` | Type 1 | One row per year | year, decade, tv_era, period | Generated (1900–2030) |
| `dim_title` | Type 2 | One row per TV series | sk_title, primaryTitle, startYear, endYear, runtimeMinutes, sk_genre_group | title_basics |
| `dim_season` | Type 1 | One row per (series, season) | sk_season_id, sk_title, sk_season | title_episode |
| `dim_genre` | Type 1 | One row per genre | sk_genre, genre_nm, category | title_basics (exploded) |
| `dim_episode` | Type 1 | One row per episode | sk_episode, sk_title, sk_season, episode_num | title_episode |
| `dim_person` | Type 1 | One row per person | sk_person, primaryName, birthYear, deathYear, sk_profession_group | name_basics |
| `dim_profession` | Type 1 | One row per profession | sk_profession, profession_nm | name_basics (exploded) |
| `bridge_genres` | — | One row per (title, genre) | sk_title, sk_genre, sk_genre_group, weighting_factor_gen | title_basics |
| `bridge_profession_group` | — | One row per (person, profession) | sk_person, sk_profession, sk_profession_group, weight_factor_prf | name_basics |
 
> **Design note:** `dim_season` contains **only descriptive attributes** — no measures. All measures (`avg_rating`, `total_votes`, `num_episodes`) live exclusively in `fact_series_performance`.

### Facts Dictionary (Summary)

#### fact_series_performance (Periodic Snapshot)
 
| | |
|:---|:---|
| **Grain** | One row per series × season × release year × genre |
| **Type** | Periodic Snapshot |
 
| Measure | Type | SQL Type | Formula (ETL) |
|:---|:---:|:---:|:---|
| `num_episodes` | Additive | SMALLINT | `COUNT(sk_episode)` aggregated from dim_episode |
| `total_runtime_min` | Additive | INTEGER | `SUM(runtimeMinutes)` |
| `total_votes` | Additive | INTEGER | `SUM(numVotes)` |
| `avg_rating` | Semi-additive | NUMERIC(3,1) | `AVG(averageRating)` |
| `rating_max` | Semi-additive | NUMERIC(3,1) | `MAX(averageRating)` |
| `rating_min` | Semi-additive | NUMERIC(3,1) | `MIN(averageRating)` |
| `stddev_rating` | Semi-additive | NUMERIC(4,2) | `STDDEV(averageRating)` |
 
> **Note:** Semi-additive measures (`avg_rating`, `stddev_rating`) can be compared within the same series/period but **MUST NOT be summed** across different series.
 
#### fact_ratings (Transaction Fact)
 
| | |
|:---|:---|
| **Grain** | One row per episode × person × profession |
| **Type** | Transaction Fact |
 
| Measure | Type | SQL Type | Formula |
|:---|:---:|:---:|:---|
| `average_rating` | Semi-additive | NUMERIC(3,1) | `averageRating` from title_ratings |
| `num_votes` | Additive | INTEGER | `numVotes` from title_ratings |
 
#### participations_pers (Factless Fact)
 
| | |
|:---|:---|
| **Grain** | One row per person × title × role |
| **Type** | Factless Fact Table |
 
| Measure | Type | Notes |
|:---|:---:|:---|
| `participation_count` | Additive | Always = 1, used as additive counter |
| `runtimeMinutes` | Semi-additive | Denormalized from dim_title |
 

---

## 3. Dimensional Data Model

The model is built on three primary Star Schemas:
 
- **fact_series_performance** — TV series market performance, aggregated at season level
- **fact_ratings** — Episode-level ratings linked to cast and crew
- **participations_pers** — Factless fact linking people to titles via bridge tables

### Example: dim_series (Dummy Data)
| sk_series | tconst | primaryTitle | startYear |
| :--- | :--- | :--- | :--- |
| 1001 | tt0903747 | Breaking Bad | 2008 |
| 1002 | tt0944947 | Game of Thrones | 2011 |

### Example: fact_series_performance (Dummy Data)
| sk_series | sk_time | season_num | avg_rating | num_episodes | total_votes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 1001 | 2008 | 1 | 8.8 | 7 | 155000 |
| 1001 | 2009 | 2 | 9.0 | 13 | 162000 |
| 1002 | 2011 | 1 | 9.1 | 10 | 210000 |

> **Note:** *[Placeholder for UML Model Image]* > The model utilizes Bridge Tables (e.g., `bridge_genres`) to ensure that a series with multiple genres (e.g., "Drama", "Crime") does not result in double-counting measures during aggregation.

---

## 4. Data Sources selection. Extraction, transformation and loading.

For better structure the data enrichment we divided the data layers in bronze (raw data), silver (dims and facts transformed) and gold (if needed snapshots or aggregations). 

Data Source:
The data was sourced from the IMDb public TSV files. Given the size of the files (e.g., `title.akas` or `title.principals`), we followed a strict ETL pipeline:

1.  **Extraction:** Using our `Loader` class, we ingested Parquet-formatted data into a PostgreSQL staging area. To prevent memory saturation, the loader processes data in **batches of 25,000 rows** using `pyarrow`.
2.  **Transformation:** Handled via the `Transformer` classes, where we applied business logic filters (filtering for `titleType = 'tvSeries'`, years $\ge 2000$, and removing adult content). During this stage, we also generated surrogate keys and calculated aggregated measures like the `stddev_rating` for season quality variance.
3.  **Loading:** The final step involves populating the Star Schema tables. We used an "Append" strategy for the facts and an "Upsert" (or Type 1/Type 2) logic for dimensions to maintain historical accuracy.

## Bronze Layer Transformations

### 1. Data Extraction

Raw data source files from IMDB:
- `name.basics.tsv` - Participant information (9.5M+ records)
- `title.basics.tsv` - Title information (11.5M+ records)
- `title.principals.tsv` - Participation records (42M+ records)
- `title.episode.tsv` - Episode information
- `title.ratings.tsv` - Rating data

### 2. Initial Filtering - TV Series Focus

Created `dim_filter` table to establish filtering criteria: 
- titleType = 'tvSeries'
- startYear >= 2000
- isAdult = 0


**Impact:**
- Initial records: ~11.5M all titles → **Filtered TV Series: ~300K records**
- This filter cascades through all dimensional tables via inner joins
- Ensures data consistency and referential integrity

### 3. Dimensional Table Creation with Filtering

#### dim_profession & bridge_profession_group
**Purpose:** Normalize participant professions (many-to-many relationship)

**Transformation Logic:**
```
Input: name_basics.primaryProfession (comma-separated)
└─→ Split & Explode
    └─→ Create dim_profession (unique professions)
        └─→ Map profession IDs
            └─→ Create bridge_profession_group
                └─→ Apply dim_filter (keep only TV series participants)
                    └─→ Calculate weighting_factor_prf = 1/count(professions per person)
```

**Key Metrics:**
- Unique professions in dataset: 32
- Participants with professions (TV series): ~50K
- Average professions per participant: 1.3

#### dim_person
**Purpose:** Central participant dimension with biographical data

**Transformation Logic:**
```
Input: name.basics filtered records
└─→ Select: nconst, primaryName, birthYear, deathYear
    └─→ Join with bridge_profession_group
        └─→ Extract profession_group_id
            └─→ Apply dim_filter on nconst
Output: Unique participants with demographic & profession data
```


#### dim_roles
**Purpose:** Detailed role information for each participation

**Transformation Logic:**
```
Input: title_principals + title_basics (filtered)
└─→ Create role_id = nconst + tconst + ordering
    └─→ Join with title_basics to get titleType
        └─→ Apply dim_filter on both nconst & tconst
Output: 800K+ detailed role records
```

**Columns:** role_id, nconst, tconst, titleType, category, job, characters

#### dim_title_basic
**Purpose:** Title metadata and genre associations

**Transformation Logic:**
```
Input: title_basics filtered for TV series
└─→ Select: tconst, titleType, primaryTitle, originalTitle, 
           isAdult, startYear, endYear, runtimeMinutes
    └─→ Join with bridge_genres to get genre_group_id
        └─→ Apply dim_filter on tconst
```

#### dim_genre & bridge_genres
**Purpose:** Normalize genre information

**Transformation Logic:**
```
Input: title_basics.genres (comma-separated)
└─→ Split & Explode
    └─→ Create dim_genres (unique genres: 28)
        └─→ Create bridge_genres
            └─→ Calculate genre_group_id per title
                └─→ weighting_factor_gen = 1/count(genres per title)
                    └─→ Apply dim_filter
```

#### bridge_kwn_titles
**Purpose:** Known titles mentioned in participant profiles

**Transformation Logic:**
```
Input: name_basics.knownForTitles (comma-separated tconst)
└─→ Split & Explode
    └─→ Create bridge_kwn_titles
        └─→ Calculate kwn_title_group_id
            └─→ weighting_factor_grp = 1/count(known titles per person)
                └─→ Apply dim_filter on both nconst & tconst
```



---

## 5. Querying and Data Analysis

We have defined some questions to guide our analysis. (TODO)

| Research Questions — TV Series Market Analysis (IMDb)               |                                                                                                                                                        |
|---------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------|
| Project 3 | Data Warehouse — Master in Data Science and Engineering |                                                                                                                                                        |
| #                                                                   | Research Question                                                                                                                                      |
| Q1                                                                  | Do series with more seasons have better or worse ratings over time?<br>Is there a 'quality fatigue' point as seasons increase?                         |
| Q2                                                                  | Which TV genres dominated each decade and how did their average quality evolve?<br>From Westerns to Drama to Reality — what trends emerge?             |
| Q3                                                                  | Do shorter series (1–2 seasons) have more consistent ratings than long-running ones?<br>Comparing quality variance: mini-series vs sagas.              |
| Q4                                                                  | How has audience engagement (votes) in TV series evolved across decades?<br>Have series become more popular and when did streaming change the pattern? |
| Q5                                                                  | Which genres consistently receive the highest average ratings?                                                                                         |
| Q6                                                                  | Which genres are consistently the most popular based on the number of votes?                                                                           |
| Q7                                                                  | Who are the top 10 directors whose movies have the highest average rating with at least 100,000 total votes?                                           |
| Q8                                                                  | Who are the top 10 actors whose movies have the highest average rating with at least 100,000 total votes?                                              |
| Q9                                                                  | What is the correlation between the total number of episodes in a series and its overall average rating?                                               |
| Q10                                                                 | At what point (season/episode number) do highly-rated series typically start to see a significant decline in user ratings? (Jum the Shark effect)      |
| Q11                                                                 | Is there a statistically significant difference between a series' average rating and the rating of its final episode? (Series finale performance)      |
| Q12                                                                 | Who are the most active participants in the IMDB dataset by number of participations across different title types?                                     |
| Q13                                                                 | Which participants have accumulated the highest total runtime across all their participations?                                                         |
| Q14                                                                 | Which participants have the most known for titles listed in their profiles  and how does this correlate with their actual participation count?         |
| Q15                                                                 | Which participants have worked across the most distinct genres throughout their careers?                                                               |
| Q16                                                                 | Which pairs of participants have the strongest collaborative relationships appearing together in the most titles?                                      |
| Q17                                                                 | Which decades had the most active participants overall  and how has the rate of industry participation evolved across decades?                         |
| Q18                                                                 | In which decade did each participant reach their career peak in terms of participation frequency  and what is the overall span of their career?        |
| Q19                                                                 | Does episode count per season affect perceived quality? Do shorter seasons rate higher?                                                                |

---

## 6. Visualization

To communicate the findings, the following visualizations are implemented:
* **Heatmaps:** To cross-reference Decades vs. Genres, with color intensity representing the average rating.
* **Line Charts:** To plot the "Quality Fatigue" (Season Number vs. Avg Rating) for the top 50 most-voted series.
* **Network Graphs:** To visualize the "Strongest Collaborations" (Q16), where nodes represent people and edge weights represent shared projects.
* **Dual-Axis Charts:** Comparing the number of unique participants vs. the total number of series produced per year.

### Q1 — Global Rating Trend by Season
 
> *[Insert Power BI screenshot — Q1 page]*
 
**Visual 1 — Global Rating Trend (all series):** Line chart with linear regression trendline. X-axis: `sk_season` (filtered ≤ 20), Y-axis: `Avg Rating`. The trendline descends from 7.6 (season 1) to ~7.0 (season 20), providing statistical confirmation of quality fatigue across the full dataset.
 
**Visual 2 — Top 10 Most Voted Series (exploratory):** Line chart with one line per series, filtered to Top 10 by Total Votes. Game of Thrones is highlighted — its collapse from 9.1 in season 7 to 6.3 in season 8 is the most dramatic quality fatigue case in the dataset. Breaking Bad terminates at its peak (season 4-5), illustrating the alternative strategy.
 
### Q2 — Genre Quality Heatmap
 
> *[Insert Power BI screenshot — Q2 page]*
 
**Visual 1 — Heatmap:** Matrix visual with conditional formatting (red = low, green = high). Rows: year (2000–2021), Columns: genre_nm, Values: `Avg Rating`. Reveals Musical as a high-rating but low-volume genre, and Reality-TV as consistently the lowest-rated genre.
 
**Visual 2 — Rating Trend by Genre:** Line chart showing the top 5 most represented genres (Comedy, Documentary, Drama, Reality-TV, Talk-Show) from 2000 to 2021. Lines are nearly parallel and stable between 6.5–8.0, indicating that genre quality perception did not change significantly over the period.
 
### Q3 — Consistency by Series Length
 
> *[Insert Power BI screenshot — Q3 page]*
 
**Visual 1 — Avg Stddev by Longevity Group:** Bar chart showing quality variance per group. Mini-series have unexpectedly high variance; Short and Medium series are the most consistent.
 
**Visual 2 — Avg Rating by Longevity Group:** Bar chart showing Medium (4–6 seasons) as the highest-rated group and Long (7+) as the lowest.
 
### Q4 — Audience Engagement Evolution
 
> *[Insert Power BI screenshot — Q4 page]*
 
**Visual 1 — Dual-axis line chart:** Total Votes (primary Y-axis) and Avg Rating (secondary Y-axis) by year. Two vertical reference lines mark the Quality Era (2000) and the Streaming Era (2013). The vote peak around 2011–2012 followed by a post-2013 decline is clearly visible.
 
**Visual 2 — Top 10 Most Voted Series:** Bar chart showing Game of Thrones dominating with >10M votes — nearly double the second-place series (The Walking Dead).
 
### Q5 — Episode Count Impact
 
> *[Insert Power BI screenshot — Q5 page]*
 
**Visual 1 — Avg Rating by Season Length:** Bar chart showing Short (6–10 ep) as the highest-rated group.
 
**Visual 2 — Avg Stddev by Season Length:** Bar chart showing Long (20+ ep) as the most inconsistent group, with stddev ~0.55 versus ~0.38 for Very Short seasons.
 
### Visualizations for Q6–Q18
 

## 7. Conclusion and Critical Reflection

The implementation of this Data Warehouse demonstrates the clear advantage of OLAP systems for analytical workloads. By de-normalizing the IMDb data, we reduced query times for complex aggregations (like standard deviation of ratings across thousands of episodes) from minutes to seconds compared to the operational relational model.

**Shortcomings:** The main challenge remains the ETL latency; as the IMDb dataset updates, the heavy transformation logic required for bridge tables and surrogate key mapping takes significant time.  
**Advantages:** The resulting "Gold" layer is highly intuitive for end-users, shielding them from the complexity of the original 7+ table joins required in the operational database. This project successfully provides a scalable foundation for modern TV market intelligence.

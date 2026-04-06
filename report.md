# IMDb TV Series Market Analysis: Data Warehouse Lab Report

**Course:** Master in Data Science and Engineering (MECD)  
**Subject:** Data Warehouses  
**Professor:** Gabriel David  
**Authors:** Davi Santos, André de Oliveira, Daniel Martinez  

---

## 1. Subject Description and Goals

The core of this project is the design and implementation of a dimensional model based on the IMDb dataset to analyze the global TV Series market. While the source data is vast, covering everything from cinema to documentaries, our objective is to isolate and study **TV Series** released from the year **2000 onwards**, excluding adult content. This specific subset allows for a manageable yet "Big Data" scale analysis of modern television trends.

The primary goals are to evaluate series performance through ratings and viewer engagement, and to map the professional networks of the cast and crew (participations). By moving from an operational, normalized structure to a de-normalized star schema, we aim to facilitate complex analytical queries such as identifying "quality fatigue" across seasons or detecting high-impact collaborations between industry professionals.

---

## 2. Planning: Dimensional Bus Matrix, Dimensions and Facts Dictionary

Our planning phase was guided by the need for conformed dimensions, ensuring that entities like "Series" or "Time" remain consistent across different analysis stars.

### Dimensional Bus Matrix
The following matrix illustrates how our facts interact with shared dimensions:

| Data Mart | Fact / Star | dim_time | dim_series | dim_season | dim_episode | dim_genre | bridge_genres | dim_person | dim_profession | dim_role|
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |:---: |:---: |
| **TV Series** | Episode Snapshot | X | X | X | | X | | | | |
| **TV Series** | Episode Talent | X | | | X | | X | X | X| |
| **TV Series** | Participations | | | | | | | X | X | X |

### Dimensions Dictionary (Summary)
 
 TODO

### Facts Dictionary (Summary)

TODO

---

## 3. Dimensional Data Model

The model is built on two primary Star Schemas. The **Episode Snapshot Star** is used for performance analysis. It aggregates episode-level data into seasons, allowing us to see how a series evolves over time. The **Participations Star** acts as a link between people and titles, utilizing bridge tables to handle the multiple professions a person might have.

### Example: dim_series (Dummy Data)
| sk_series | tconst | primaryTitle | startYear |
| :--- | :--- | :--- | :--- |
| 1001 | tt0903747 | Breaking Bad | 2008 |
| 1002 | tt0944947 | Game of Thrones | 2011 |

### Example: fact_episode_snapshot (Dummy Data)
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
|                                                                     |                                                                                                                                                        |

---

## 6. Visualization

To communicate the findings, the following visualizations are implemented:
* **Heatmaps:** To cross-reference Decades vs. Genres, with color intensity representing the average rating.
* **Line Charts:** To plot the "Quality Fatigue" (Season Number vs. Avg Rating) for the top 50 most-voted series.
* **Network Graphs:** To visualize the "Strongest Collaborations" (Q16), where nodes represent people and edge weights represent shared projects.
* **Dual-Axis Charts:** Comparing the number of unique participants vs. the total number of series produced per year.

---

## 7. Conclusion and Critical Reflection

The implementation of this Data Warehouse demonstrates the clear advantage of OLAP systems for analytical workloads. By de-normalizing the IMDb data, we reduced query times for complex aggregations (like standard deviation of ratings across thousands of episodes) from minutes to seconds compared to the operational relational model.

**Shortcomings:** The main challenge remains the ETL latency; as the IMDb dataset updates, the heavy transformation logic required for bridge tables and surrogate key mapping takes significant time.  
**Advantages:** The resulting "Gold" layer is highly intuitive for end-users, shielding them from the complexity of the original 7+ table joins required in the operational database. This project successfully provides a scalable foundation for modern TV market intelligence.
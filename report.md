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

| Data Mart | Fact / Star | dim_time | dim_series | dim_season | dim_episode | dim_genre | dim_person | dim_role |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **TV Series** | Episode Snapshot | X | X | X | | X | | |
| **TV Series** | Episode Talent | X | | | X | | X | |
| **TV Series** | Participations | | | | | | X | X |

### Dimensions Dictionary (Summary)
Dimensions are stored as SCD (Slowly Changing Dimensions) where applicable. We utilize surrogate keys (SERIAL) to ensure integrity.

* **dim_time:** Includes hierarchies for Year < Decade < TV Era.
* **dim_series:** Contains metadata about the show (Title, Start Year, End Year).
* **dim_person:** Information about actors and crew members (Name, Birth/Death Year).
* **bridge_genres:** A bridge table to resolve the many-to-many relationship between titles and multiple genre tags.

### Facts Dictionary (Summary)
We implemented two distinct types of fact tables to meet the assignment requirements:

1.  **Episode Snapshot (Periodic Snapshot):** Captures performance metrics at a season granularity.
    * *Additive:* `num_episodes`, `total_votes`, `total_runtime_min`.
    * *Semi-additive:* `avg_rating` (Weighted), `stddev_rating` (Quality variance).
2.  **Participations (Factless Fact Table):** Maps every instance of a person working on a title.
    * *Measure:* `participation_count` (Constant 1).

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

The data was sourced from the IMDb public TSV files. Given the size of the files (e.g., `title.akas` or `title.principals`), we followed a strict ETL pipeline:

1.  **Extraction:** Using our `Loader` class, we ingested Parquet-formatted data into a PostgreSQL staging area. To prevent memory saturation, the loader processes data in **batches of 25,000 rows** using `pyarrow`.
2.  **Transformation:** Handled via the `Transformer` classes, where we applied business logic filters (filtering for `titleType = 'tvSeries'`, years $\ge 2000$, and removing adult content). During this stage, we also generated surrogate keys and calculated aggregated measures like the `stddev_rating` for season quality variance.
3.  **Loading:** The final step involves populating the Star Schema tables. We used an "Append" strategy for the facts and an "Upsert" (or Type 1/Type 2) logic for dimensions to maintain historical accuracy.

---

## 5. Querying and Data Analysis

We have defined 7 core research questions to test the utility of the warehouse:

* **Q1: Quality Fatigue:** Does the average rating drop as the number of seasons increases?
* **Q2: Genre Dominance:** Which genres have the highest "Market Share" (count of titles) per decade?
* **Q15: Professional Versatility:** Which participants have worked across the highest number of distinct genres?
* **Q16: Industry Partnerships:** Identify the top 10 pairs of professionals who have collaborated on the most titles.
* **Q17: Participation Trends:** Analyzing the growth of unique industry participants per decade since 2000.
* **Q18: Career Peaks:** Identifying the "Peak Decade" for actors based on their participation frequency.

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
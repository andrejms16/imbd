import pandas as pd
import gc
from pathlib import Path
from src.imdb_utils import utils


class Transformer:
    def __init__(self):
        """
        Initializes the Transformer with project paths and internal state.
        """
        self.project_root = Path.cwd()
        self.raw_path = self.project_root / "data/bronze/imdb_raw_data"
        self.silver_path = self.project_root / "data/silver"

        self.silver_path.mkdir(parents=True, exist_ok=True)

        self.title_basics = None
        self.title_principals = None
        self.name_basics = None
        self.title_episodes = None
        self.dim_filter = None
        self.ratings = None

    def _load_raw_files(self):
        """
        Loads raw TSV files from the bronze layer.
        """
        print("Reading raw files from bronze...")
        self.title_basics = pd.read_csv(self.raw_path / 'title.basics.tsv/data.tsv',
                                        sep='\t', na_values='\\N', low_memory=False)
        self.title_principals = pd.read_csv(self.raw_path / 'title.principals.tsv/data.tsv',
                                            sep='\t', na_values='\\N')
        self.name_basics = pd.read_csv(self.raw_path / 'name.basics.tsv/data.tsv',
                                       sep='\t', na_values='\\N')
        self.title_episodes = pd.read_csv(self.raw_path / 'title.episode.tsv/data.tsv',
                                          sep='\t', na_values='\\N')

    def transform_dim_filter(self):
        """
        Creates the master filter and standardizes keys to sk_title and sk_person.
        """
        print("Transforming: dim_filter")
        self.title_basics = self.title_basics[
            (self.title_basics['titleType'] == 'tvSeries') &
            (self.title_basics['isAdult'] == 0) &
            (pd.to_numeric(self.title_basics['startYear'], errors='coerce') >= 2000)
            ].copy()

        # Standardizing names: tconst -> sk_title, nconst -> sk_person
        self.dim_filter = self.title_basics[['tconst', 'titleType', 'isAdult']].merge(
            self.title_principals[['tconst', 'nconst']],
            on='tconst',
            how='inner'
        ).drop_duplicates().rename(columns={'tconst': 'sk_title', 'nconst': 'sk_person'})

        self.dim_filter.to_parquet(self.silver_path / 'dim_filter.parquet')

    def transform_dim_episode(self):
        """
        Creates dim_episode linked to the filtered series universe,
        avoiding duplicate columns.
        """
        print("Transforming: dim_episode")

        # 1. Filter: Only keep episodes whose parent series is in our dim_filter
        # Use only the 'sk_title' column from dim_filter for the merge
        dim_episode = self.title_episodes.merge(
            self.dim_filter[['sk_title']].drop_duplicates(),
            left_on='parentTconst',
            right_on='sk_title',
            how='inner'
        )

        # 2. Rename columns
        # Note: 'sk_title' already exists from the right table,
        # so we don't need to rename 'parentTconst' to it again.
        # We just drop the redundant 'parentTconst' column.
        dim_episode = dim_episode.rename(columns={
            'tconst': 'sk_episode',
            'seasonNumber': 'sk_season',
            'episodeNumber': 'episode_num'
        })

        # 3. Select unique columns and handle types
        # We ensure sk_title is included only once
        dim_episode = dim_episode[['sk_episode', 'sk_title', 'sk_season', 'episode_num']]

        # Convert to numeric to handle '\N' values
        dim_episode['sk_season'] = pd.to_numeric(dim_episode['sk_season'], errors='coerce')
        dim_episode['episode_num'] = pd.to_numeric(dim_episode['episode_num'], errors='coerce')

        # 4. Save to Parquet
        dim_episode.to_parquet(self.silver_path / 'dim_episode.parquet', compression='snappy')
        print(f"dim_episode saved. Shape: {dim_episode.shape}")

        return dim_episode

    def transform_professions(self):
        """
        Standardizes professions with sk_profession and sk_profession_group.
        """
        print("Transforming: professions")
        unique_profs = self.name_basics['primaryProfession'].str.split(',').explode().dropna().unique()
        dim_prof = pd.DataFrame({'profession_nm': sorted(unique_profs)})
        dim_prof['sk_profession'] = [f'prf_{i + 1}' for i in range(len(dim_prof))]

        bridge = (
            self.name_basics[['nconst', 'primaryProfession']]
            .dropna(subset=['primaryProfession'])
            .assign(profession_nm=lambda x: x['primaryProfession'].str.split(','))
            .explode('profession_nm')
        )
        bridge = bridge.merge(dim_prof, on='profession_nm').rename(columns={'nconst': 'sk_person'})
        bridge['sk_profession_group'] = 'p_grp_' + (bridge.groupby('sk_person').ngroup() + 1).astype(str)

        bridge = bridge.merge(self.dim_filter[['sk_person']].drop_duplicates(), on='sk_person', how='inner')
        bridge['weight_factor_prf'] = 1 / bridge.groupby('sk_person')['sk_profession'].transform('count')

        dim_prof.to_parquet(self.silver_path / 'dim_profession.parquet')
        bridge[['sk_person', 'sk_profession', 'sk_profession_group', 'weight_factor_prf']].to_parquet(
            self.silver_path / 'bridge_profession_group.parquet')
        return bridge

    def transform_genres(self):
        """
        Standardizes genres with sk_genre and sk_genre_group.
        """
        print("Transforming: genres")
        unique_gen = self.title_basics['genres'].str.split(',').explode().dropna().unique()
        dim_gen = pd.DataFrame({'genre_nm': sorted(unique_gen)})
        dim_gen['sk_genre'] = [f'gen_{i + 1}' for i in range(len(dim_gen))]

        bridge = (
            self.title_basics[['tconst', 'genres']]
            .dropna(subset=['genres'])
            .assign(genre_nm=lambda x: x['genres'].str.split(','))
            .explode('genre_nm')
        )
        bridge = bridge.merge(dim_gen, on='genre_nm').rename(columns={'tconst': 'sk_title'})
        bridge['sk_genre_group'] = 'g_grp_' + (bridge.groupby('sk_title').ngroup() + 1).astype(str)
        bridge['weight_factor_gen'] = 1 / bridge.groupby('sk_title')['sk_genre'].transform('count')

        bridge = bridge.merge(self.dim_filter[['sk_title']].drop_duplicates(), on='sk_title', how='inner')

        dim_gen.to_parquet(self.silver_path / 'dim_genres.parquet')
        bridge[['sk_title', 'sk_genre', 'sk_genre_group', 'weight_factor_gen']].to_parquet(
            self.silver_path / 'bridge_genres.parquet')
        return bridge

    def transform_dim_person(self, bridge_prof):
        """
        Creates dim_person with sk_person and sk_profession_group.
        """
        print("Transforming: dim_person")
        dim_person = self.name_basics[['nconst', 'primaryName', 'birthYear', 'deathYear']].rename(
            columns={'nconst': 'sk_person'})
        dim_person = dim_person.merge(bridge_prof[['sk_person', 'sk_profession_group']].drop_duplicates(),
                                      on='sk_person', how='inner')
        dim_person.to_parquet(self.silver_path / 'dim_person.parquet')

    def transform_dim_title(self, bridge_gen):
        """
        Creates dim_title with sk_title and sk_genre_group.
        """
        print("Transforming: dim_title")
        dim_title = self.title_basics[
            ['tconst', 'titleType', 'primaryTitle', 'originalTitle', 'startYear', 'endYear', 'runtimeMinutes']].rename(
            columns={'tconst': 'sk_title'})
        dim_title = dim_title.merge(bridge_gen[['sk_title', 'sk_genre_group']].drop_duplicates(), on='sk_title',
                                    how='left')
        dim_title['runtimeMinutes'] = pd.to_numeric(dim_title['runtimeMinutes'], errors='coerce')
        dim_title.to_parquet(self.silver_path / 'dim_title_basic.parquet')
        return dim_title

    def transform_fact_participations(self, dim_title):
        """
        Creates fact table with standardized sk_ keys.
        """
        print("Transforming: fact_participations")
        dim_roles = self.title_principals.rename(columns={'tconst': 'sk_title', 'nconst': 'sk_person'})
        dim_roles = dim_roles.merge(self.dim_filter[['sk_person', 'sk_title']].drop_duplicates(),
                                    on=['sk_person', 'sk_title'], how='inner')
        dim_roles['sk_role'] = dim_roles['sk_person'] + '_' + dim_roles['sk_title'] + '_' + dim_roles[
            'ordering'].astype(str)

        fact = dim_title[['sk_title', 'titleType', 'primaryTitle', 'sk_genre_group', 'runtimeMinutes']].merge(
            dim_roles[['sk_role', 'sk_title', 'sk_person', 'category', 'job', 'characters']],
            on='sk_title', how='left'
        )
        fact['participation_count'] = 1
        fact.to_parquet(self.silver_path / 'participations_pers.parquet', compression='snappy')

    def transform_fact_ratings(self, dim_title, dim_episode):
        """
        Creates the fact_ratings table by joining episodes, ratings, and principals.
        This expands ratings to every person involved in the episode.
        """
        print("Transforming: fact_ratings")

        # 1. Load ratings data (Make sure to add this to _load_raw_files)
        ratings = pd.read_csv(self.raw_path / 'title.ratings.tsv/data.tsv',
                              sep='\t', na_values='\\N')

        # 2. Filter ratings: Only keep ratings for episodes in our dim_episode
        # This ensures we respect the "TV Series + Post-2000" filter
        fact_ratings = ratings.merge(
            dim_episode[['sk_episode', 'sk_title']],
            left_on='tconst',
            right_on='sk_episode',
            how='inner'
        )

        # 3. Join with principals to get the people involved in each episode
        # We join on sk_episode (which is the tconst of the episode)
        fact_ratings = fact_ratings.merge(
            self.title_principals.rename(columns={'tconst': 'sk_episode', 'nconst': 'sk_person'}),
            on='sk_episode',
            how='inner'
        )

        # 4. Join with dim_title to bring sk_genre_group
        # Note: dim_title contains the sk_genre_group of the PARENT series
        fact_ratings = fact_ratings.merge(
            dim_title[['sk_title', 'sk_genre_group']],
            on='sk_title',
            how='left'
        )

        # 5. Create sk_role (Standardized as person_episode_ordering)
        fact_ratings['sk_role'] = (
                fact_ratings['sk_person'] + '_' +
                fact_ratings['sk_episode'] + '_' +
                fact_ratings['ordering'].astype(str)
        )

        # 6. Final selection and renaming
        fact_ratings = fact_ratings.rename(columns={
            'averageRating': 'average_rating',
            'numVotes': 'num_votes'
        })

        columns_to_keep = [
            'sk_episode', 'sk_person', 'sk_genre_group',
            'sk_role', 'average_rating', 'num_votes'
        ]

        fact_ratings = fact_ratings[columns_to_keep]

        # 7. Save to Parquet
        fact_ratings.to_parquet(self.silver_path / 'fact_ratings.parquet', compression='snappy')
        print(f"fact_ratings saved. Shape: {fact_ratings.shape}")

    def run_pipeline(self):
        """
        Orchestrates the standardized ETL flow.
        """
        print("=== Starting Standardized ETL Pipeline ===")
        self._load_raw_files()
        self.transform_dim_filter()
        dim_episode = self.transform_dim_episode()

        bridge_prof = self.transform_professions()
        bridge_gen = self.transform_genres()

        self.transform_dim_person(bridge_prof)
        dim_title = self.transform_dim_title(bridge_gen)
        self.transform_fact_participations(dim_title)
        self.transform_fact_ratings(dim_title, dim_episode)  # New Fact Table

        print("=== ETL Pipeline Finished Successfully ===")
        gc.collect()
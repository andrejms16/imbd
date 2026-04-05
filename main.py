from transformer import Transformer
from pathlib import Path
from loader import Loader


if __name__ == "__main__":
    
    # transformer = Transformer()
    # transformer.run_pipeline()
    
    DB_CONFIG = {
        "db_user": "postgres",
        "db_password": "datawarehouse2026",
        "db_host": "imdb.czy6ewi2uruh.us-east-1.rds.amazonaws.com",
        "db_port": "5432",
        "db_name": "imdb"
    }

    silver_path = Path.cwd() / "data/silver"
    loader = Loader(**DB_CONFIG)

    files_to_load = [
        # ("bridge_genres.parquet", "bridge_genres"),
        ("bridge_kwn_titles.parquet", "bridge_kwn_titles"),
        # ("bridge_profession_group.parquet", "bridge_profession_group"),
        # ("dim_episode.parquet", "dim_episode"),
        # ("dim_filter.parquet", "dim_filter"),
        # ("dim_genres.parquet", "dim_genres"),
        # ("dim_person.parquet", "dim_person"),
        ("dim_roles.parquet", "dim_roles"),
        # ("dim_profession.parquet", "dim_profession"),
        # ("dim_title_basic.parquet", "dim_title"),
        # ("fact_ratings.parquet", "fact_ratings"),
        ("participations_pers.parquet", "fact_participations")
        #("dim_season.parquet", "dim_season"),
        #("dim_series.parquet", "dim_series"),
        #("fact_series_performance.parquet", "fact_series_performance")
    ]

    for file_name, table_name in files_to_load:
        file_path = silver_path / file_name
        if file_path.exists():
            loader.load_parquet_to_postgres(file_path, table_name, batch_size=25000)
        else:
            print(f"File not found: {file_path}")

    loader.close_connection()


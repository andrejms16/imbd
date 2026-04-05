import pandas as pd
import pyarrow.parquet as pq
from sqlalchemy import create_engine
import gc


class Loader:
    def __init__(self, db_user, db_password, db_host, db_port, db_name):
        self.connection_string = f'postgresql://{db_user}:{db_password}@{db_host}:{db_port}/{db_name}'
        self.engine = create_engine(self.connection_string)
        print(f"Connected to database: {db_name}")

    def load_parquet_to_postgres(self, file_path, table_name, batch_size=25000, if_exists='append'):
        """
                Reads a Parquet file in batches and loads them into PostgreSQL
                to prevent memory saturation.
        """
        print(f"--- Loading {file_path.name} into table '{table_name}' ---")
        try:
            # Open the parquet file as a ParquetFile object to read metadata/batches
            parquet_file = pq.ParquetFile(file_path)
            # Iterate through the file in row groups or batches
            # iter_batches returns an iterator of RecordBatches
            for batch in parquet_file.iter_batches(batch_size=batch_size):
                # Convert the specific batch to a pandas DataFrame
                df_chunk = batch.to_pandas()

                # Upload the chunk to SQL
                df_chunk.to_sql(
                    name=table_name,
                    con=self.engine,
                    if_exists=if_exists,
                    index=False,
                    method='multi',  # Optimizes insertion speed
                    chunksize=batch_size
                )

                print(f"Successfully loaded a batch of {len(df_chunk)} rows.")
                # Explicit memory management
                del df_chunk
                gc.collect()

                # After the first batch, we must 'append' to avoid overwriting the table
                if_exists = 'append'
            print(f"Finished loading {table_name} successfully.\n")
        except Exception as e:
            print(f"Error loading {table_name}: {e}")

    def close_connection(self):
        """
        Disposes the database engine.
        """
        self.engine.dispose()
        print("Database connection closed.")
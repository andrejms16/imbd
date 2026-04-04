def select_cols(df, cols_to_keep):
    """
    Selects specified columns from a DataFrame.

    Parameters:
    df (pd.DataFrame): The input DataFrame.
    cols (list): A list of column names to select.

    Returns:
    pd.DataFrame: A DataFrame containing only the selected columns.
    """
    cols_to_drop = [col for col in df.columns if col not in cols_to_keep]
    df.drop(columns=cols_to_drop, inplace=True)
    df = df.loc[:, cols_to_keep]
    return df
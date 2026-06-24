import snowflake.connector
import os
from dotenv import load_dotenv
import pandas as pd

load_dotenv()

conn = snowflake.connector.connect(
    user=os.getenv("SNOWFLAKE_USER"),
    password=os.getenv("SNOWFLAKE_PASSWORD"),
    account=os.getenv("SNOWFLAKE_ACCOUNT"),
    warehouse=os.getenv("SNOWFLAKE_WAREHOUSE"),
    database=os.getenv("SNOWFLAKE_DATABASE"),
    schema=os.getenv("SNOWFLAKE_SCHEMA")
)


curr = conn.cursor()

df_main = curr.execute('SELECT * FROM heart_main').fetch_pandas_all()
df_p1 = curr.execute('SELECT * FROM heart_partial_one').fetch_pandas_all()
df_p2 = curr.execute('SELECT * FROM heart_partial_two').fetch_pandas_all()



print(df_main.dtypes)






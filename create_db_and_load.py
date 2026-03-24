import pandas as pd
import psycopg2
from psycopg2 import sql

# Define connection parameters for the default postgres database
DB_HOST = "localhost"
DB_PORT = "5434"
DB_USER = "postgres"
DB_PASSWORD = "postgres123"
NEW_DB_NAME = "Customer_Support_Tickets"

# Read CSV and extract body column
csv_path = "nifi/data/huggingface/hf_tickets.csv"
df = pd.read_csv(csv_path, usecols=['body'])

# Rename body column to description
df = df.rename(columns={'body': 'description'})

# Connect to default database to create the new DB
try:
    conn = psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASSWORD,
        dbname="postgres"
    )
    conn.autocommit = True
    cursor = conn.cursor()
    
    # Check if database exists
    cursor.execute("SELECT 1 FROM pg_database WHERE datname = %s", (NEW_DB_NAME,))
    exists = cursor.fetchone()
    if not exists:
        # Cannot be parameterized directly so use sql module
        cursor.execute(sql.SQL("CREATE DATABASE {}").format(sql.Identifier(NEW_DB_NAME)))
        print(f"Database '{NEW_DB_NAME}' created successfully.")
    else:
        print(f"Database '{NEW_DB_NAME}' already exists.")
        
    cursor.close()
    conn.close()
except Exception as e:
    print(f"Failed to create database: {e}")
    exit(1)

# Connect to the new database to create table and insert data
try:
    conn = psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASSWORD,
        dbname=NEW_DB_NAME
    )
    cursor = conn.cursor()
    
    # Create the table
    create_table_query = """
    CREATE TABLE IF NOT EXISTS tickets (
        ID SERIAL PRIMARY KEY,
        description TEXT
    )
    """
    cursor.execute(create_table_query)
    
    # Clear the table if it exists (to avoid duplicate inserts if ran multiple times)
    cursor.execute("TRUNCATE TABLE tickets RESTART IDENTITY")
    
    # Insert the data
    insert_query = "INSERT INTO tickets (description) VALUES (%s)"
    
    # Executemany for efficiency
    data_to_insert = [(row['description'],) for _, row in df.iterrows()]
    cursor.executemany(insert_query, data_to_insert)
    
    conn.commit()
    print(f"Successfully inserted {len(data_to_insert)} rows into the 'tickets' table.")
    
    cursor.close()
    conn.close()
except Exception as e:
    print(f"Failed to create table or insert data: {e}")
    exit(1)

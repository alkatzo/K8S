import psycopg2
import os
import time
import sys

def get_db_connection():
    """Get PostgreSQL database connection"""
    return psycopg2.connect(
        host=os.getenv('POSTGRES_HOST', 'localhost'),
        port=os.getenv('POSTGRES_PORT', '5432'),
        database=os.getenv('POSTGRES_DB', 'taskdb'),
        user=os.getenv('POSTGRES_USER', 'postgres'),
        password=os.getenv('POSTGRES_PASSWORD', 'postgres')
    )

def insert_tasks(conn):
    """Insert tasks into the database"""
    tasks = [
        ('Task-B-1', 'job-b'),
        ('Task-B-2', 'job-b'),
        ('Task-B-3', 'job-b'),
    ]
    
    with conn.cursor() as cursor:
        for task_name, created_by in tasks:
            cursor.execute(
                "INSERT INTO tasks (task_name, created_by) VALUES (%s, %s)",
                (task_name, created_by)
            )
            print(f"Inserted task: {task_name}")
        conn.commit()
    
    print("Job B completed successfully")

def main():
    try:
        print("Job B starting...")
        print(f"Connecting to PostgreSQL at {os.getenv('POSTGRES_HOST', 'localhost')}")
        
        # Wait for DB to be ready
        time.sleep(5)
        
        conn = get_db_connection()
        print("Connected to database")
        
        insert_tasks(conn)
        
        conn.close()
        print("Job B finished")
        sys.exit(0)
        
    except Exception as error:
        print(f"Error in Job B: {error}")
        sys.exit(1)

if __name__ == "__main__":
    main()

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

def create_tasks_table(conn):
    """Create tasks table if it doesn't exist"""
    with conn.cursor() as cursor:
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS tasks (
                id SERIAL PRIMARY KEY,
                task_name VARCHAR(255) NOT NULL,
                status VARCHAR(50) DEFAULT 'pending',
                created_by VARCHAR(50) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                completed_at TIMESTAMP
            )
        """)
        conn.commit()
        print("Tasks table created or already exists")

def insert_tasks(conn):
    """Insert tasks into the database"""
    tasks = [
        ('Task-A-1', 'job-a'),
        ('Task-A-2', 'job-a'),
        ('Task-A-3', 'job-a'),
    ]
    
    with conn.cursor() as cursor:
        for task_name, created_by in tasks:
            cursor.execute(
                "INSERT INTO tasks (task_name, created_by) VALUES (%s, %s)",
                (task_name, created_by)
            )
            print(f"Inserted task: {task_name}")
        conn.commit()
    
    print("Job A completed successfully")

def main():
    try:
        print("Job A starting...")
        print(f"Connecting to PostgreSQL at {os.getenv('POSTGRES_HOST', 'localhost')}")
        
        # Wait for DB to be ready
        time.sleep(5)
        
        conn = get_db_connection()
        print("Connected to database")
        
        create_tasks_table(conn)
        insert_tasks(conn)
        
        conn.close()
        print("Job A finished")
        sys.exit(0)
        
    except Exception as error:
        print(f"Error in Job A: {error}")
        sys.exit(1)

if __name__ == "__main__":
    main()

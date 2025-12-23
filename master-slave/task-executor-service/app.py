import psycopg2
import os
import time
import sys
from datetime import datetime

def get_db_connection():
    """Get PostgreSQL database connection"""
    return psycopg2.connect(
        host=os.getenv('POSTGRES_HOST', 'localhost'),
        port=os.getenv('POSTGRES_PORT', '5432'),
        database=os.getenv('POSTGRES_DB', 'taskdb'),
        user=os.getenv('POSTGRES_USER', 'postgres'),
        password=os.getenv('POSTGRES_PASSWORD', 'postgres')
    )

def get_pending_tasks(conn):
    """Fetch pending tasks from the database"""
    with conn.cursor() as cursor:
        cursor.execute("""
            SELECT id, task_name, created_by, created_at 
            FROM tasks 
            WHERE status = 'pending'
            ORDER BY created_at ASC
        """)
        return cursor.fetchall()

def execute_task(conn, task_id, task_name):
    """Execute a task (print to console) and mark as completed"""
    print(f"========================================")
    print(f"EXECUTING TASK: {task_name}")
    print(f"Task ID: {task_id}")
    print(f"Timestamp: {datetime.now().isoformat()}")
    print(f"========================================")
    
    # Mark task as completed
    with conn.cursor() as cursor:
        cursor.execute("""
            UPDATE tasks 
            SET status = 'completed', completed_at = CURRENT_TIMESTAMP 
            WHERE id = %s
        """, (task_id,))
        conn.commit()
    
    print(f"Task {task_name} marked as completed\n")

def poll_and_execute_tasks():
    """Main loop to poll for tasks and execute them"""
    print("Task Executor Service starting...")
    print(f"Connecting to PostgreSQL at {os.getenv('POSTGRES_HOST', 'localhost')}")
    
    # Wait for DB to be ready
    time.sleep(10)
    
    try:
        conn = get_db_connection()
        print("Connected to database")
        print("Starting to poll for tasks...\n")
        
        while True:
            try:
                pending_tasks = get_pending_tasks(conn)
                
                if pending_tasks:
                    print(f"Found {len(pending_tasks)} pending task(s)")
                    for task in pending_tasks:
                        task_id, task_name, created_by, created_at = task
                        execute_task(conn, task_id, task_name)
                        time.sleep(1)  # Small delay between tasks
                else:
                    print("No pending tasks found. Waiting...")
                
                # Poll every 5 seconds
                time.sleep(5)
                
            except psycopg2.Error as db_error:
                print(f"Database error: {db_error}")
                # Try to reconnect
                conn.close()
                time.sleep(5)
                conn = get_db_connection()
                print("Reconnected to database")
                
    except KeyboardInterrupt:
        print("\nShutting down Task Executor Service...")
        conn.close()
        sys.exit(0)
    except Exception as error:
        print(f"Fatal error in Task Executor Service: {error}")
        sys.exit(1)

if __name__ == "__main__":
    poll_and_execute_tasks()

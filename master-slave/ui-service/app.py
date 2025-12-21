from flask import Flask, render_template, jsonify
from flask_cors import CORS
import psycopg2
import os
import json

app = Flask(__name__)
CORS(app)

def get_db_connection(namespace='master'):
    host_key = f'{namespace.upper()}_POSTGRES_HOST'
    host = os.getenv(host_key, 'localhost')
    
    return psycopg2.connect(
        host=host,
        port=os.getenv('POSTGRES_PORT', '5432'),
        database=os.getenv('POSTGRES_DB', 'taskdb'),
        user=os.getenv('POSTGRES_USER', 'postgres'),
        password=os.getenv('POSTGRES_PASSWORD', 'postgres123')
    )

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/tasks')
def get_tasks():
    try:
        all_tasks = []
        
        # Fetch from both namespaces
        for namespace in ['master', 'slave']:
            try:
                conn = get_db_connection(namespace)
                cur = conn.cursor()
                cur.execute("""
                    SELECT id, task_name, status, created_by, 
                           created_at, completed_at
                    FROM tasks 
                    ORDER BY id DESC
                """)
                tasks = cur.fetchall()
                cur.close()
                conn.close()
                
                for task in tasks:
                    all_tasks.append({
                        'id': f"{namespace}-{task[0]}",
                        'namespace': namespace,
                        'name': task[1],
                        'status': task[2],
                        'created_by': task[3],
                        'created_at': str(task[4]),
                        'completed_at': str(task[5]) if task[5] else None
                    })
            except Exception as e:
                print(f"Error fetching from {namespace}: {e}")
                continue
        
        return jsonify({'tasks': all_tasks})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/stats')
def get_stats():
    try:
        stats = {
            'master': {'total': 0, 'by_status': {}, 'by_creator': {}},
            'slave': {'total': 0, 'by_status': {}, 'by_creator': {}}
        }
        
        for namespace in ['master', 'slave']:
            try:
                conn = get_db_connection(namespace)
                cur = conn.cursor()
                
                # Total tasks
                cur.execute("SELECT COUNT(*) FROM tasks")
                stats[namespace]['total'] = cur.fetchone()[0]
                
                # Tasks by status
                cur.execute("SELECT status, COUNT(*) FROM tasks GROUP BY status")
                stats[namespace]['by_status'] = dict(cur.fetchall())
                
                # Tasks by creator
                cur.execute("SELECT created_by, COUNT(*) FROM tasks GROUP BY created_by ORDER BY created_by")
                stats[namespace]['by_creator'] = dict(cur.fetchall())
                
                cur.close()
                conn.close()
            except Exception as e:
                print(f"Error fetching stats from {namespace}: {e}")
                continue
        
        # Calculate combined stats
        combined = {
            'total': stats['master']['total'] + stats['slave']['total'],
            'by_namespace': {
                'master': stats['master']['total'],
                'slave': stats['slave']['total']
            },
            'master': stats['master'],
            'slave': stats['slave']
        }
        
        return jsonify(combined)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/health')
def health():
    try:
        # Check both databases
        conn_master = get_db_connection('master')
        conn_master.close()
        conn_slave = get_db_connection('slave')
        conn_slave.close()
        return jsonify({'status': 'healthy'}), 200
    except Exception as e:
        return jsonify({'status': 'unhealthy', 'error': str(e)}), 503

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=True)

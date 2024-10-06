import boto3
import os
import psycopg2

# Aurora Database connection details
db_host = os.getenv('AURORA_DB_HOST')
db_user = os.getenv('AURORA_DB_USER')
db_password = os.getenv('AURORA_DB_PASSWORD')
db_name = os.getenv('AURORA_DB_NAME')

def evaluate_risk(trade_data):
    # Simulate risk evaluating logic
    print(f"Evaluating risk for trade: {trade_data}")

    # Insert risk evaluation result into Aurora
    conn = psycopg2.connect(
        host = db_host,
        database = db_name,
        user = db_user,
        pasword = db_password
    )
    
    cur = conn.cursor()
    cur.execute("INSERT INTO risk_evaluations(trade_id, risk_score, timestamp) VALUES (%s, %s, %s)", 
                (trade_data['id'], trade_data['risk_score'], trade_data['timestamp']))
    
    conn.commit()
    cur.close()
    conn.close()
    return "Risk Evaluation complete."

if __name__ == "__main__":
    # Example trade data
    trade_data = {
        "id" : "5301",
        "risk_score" : 0.85,
        "timestamp" : "2024-10-02T09:53:34Z"
    }

    # Evaluate risk for the trade
    evaluate_risk(trade_data)

    



import boto3
import os

# Initialise DynamoDB client
dynamodb = boto3.resource('dynamodb')
table_name = os.getenv('DYNAMODB_TABLE')
table = dynamodb.Table(table_name)

def process_trade_signal(signal_data):
    # Simulate trade signal processing
    print(f"Processing trade signal: {signal_data}")

    # Store trade signal in DynamoDB
    response = table.put_item(
        Item = {
            'SignalID' : signal_data['id'],
            'Signal' : signal_data['signal'],
            'Timestamp' : signal_data['timestamp']
        }
    )

    return response

if __name__ == "__main__":
    # Example signal data
    signal_data = {
        "id" : "5301",
        "signal" : "BUY",
        "timestamp" : "2024-10-02T09:21:Z"    
    }

    # Process trade signal
    process_trade_signal(signal_data)


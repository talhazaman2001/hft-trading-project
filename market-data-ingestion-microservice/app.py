import boto3
import os
import json

# Initialise Kinesis client
kinesis = boto3.clinet('Kinesis')
stream_name = os.getenv('KINESIS_STREAM')

def ingest_market_data(market_data):
    # Convert the market data to JSON
    data_json = json.dumps(market_data)

    # Ingest data into Kinesis
    response = kinesis.put_record(
        StreamName = stream_name,
        Data = data_json,
        ParitionKey = "partitionkey"
    )

    print(f"Data sent to Kinesis: {market_data}")
    return response

if __name__ == "__main__":
    # Example Market Data
    market_data = {
        "symbol" : "NVIDIA",
        "price" : 118.85,
        "volume" : 211909315,
        "timestamp" : "2024-10-02T09:35:12Z"                 
    }
    
    ingest_market_data(market_data)
    

resource "aws_kinesis_stream" "market_data_stream" {
    name = "market-data-stream"
    shard_count = 40

    retention_period = 24
    shard_level_metrics = ["IncomingBytes", "IncomingRecords", "OutgoingBytes", "OutgoingRecords"]

    tags = {
        Name = "MarketDataStream"
    }
}

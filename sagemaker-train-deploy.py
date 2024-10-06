import boto3
import sagemaker
from sagemaker import get_execution_role
from sagemaker.inputs import TrainingInput
from sagemaker.estimator import Estimator

# Define S3 Bucket and SageMaker session
sagemaker_session = sagemaker.Session()
role = get_execution_role()

# S3 Bucket to store Training Data and Model Artifacts
s3_bucket = 's3://hft-sagemaker-bucket-talha'

# Fetch Training data 
price_trend_data_uri = f'{s3_bucket}/training_data/price_trend_data.csv'
volatility_data_uri = f'{s3_bucket}/training_data/volatility_data.csv'
anomaly_data_uri = f'{s3_bucket}/training_data/anomaly_data.csv'

# Train the XGBoost Model
def train_model(data_uri, output_path, model_name, objective, instance_type = 'ml.m5.large'):
    xgboost_container = sagemaker.image_uris.retrieve("xgboost", boto3.Session().region_name, "1.2-1")

    estimator = Estimator(
        image_uri = xgboost_container,
        role = role,
        instance_count = 1,
        instance_type = instance_type,
        output_path = output_path,
        sagemaker_session = sagemaker_session
    )

    estimator.set_hyperparameters(
        objective = objective,
        num_round = 100
    )

    # Specific training data in S3
    training_input = TrainingInput(s3_data = data_uri, content_type = 'csv')

    # Train the Model
    estimator.fit({'train': training_input})

    return estimator

# Deploy the Model
def deploy_model(estimator, endpoint_name):

    predictor = estimator.deploy(
        initial_instance_count = 1,
        instance_type = 'ml.m5.large',
        endpoint_name = endpoint_name
    )

    return predictor

if __name__ == "__main__":
    price_estimator = train_model(price_trend_data_uri, f'{s3_bucket}/training_data/price_trend', "price-trend", "reg:squarederror")
    price_predictor = deploy_model(price_estimator, "price-trend-forecast-endpoint")
    print("Print Trend Forecasting Model deployed:", price_predictor.endpoint_name)

    volatility_estimator = train_model(volatility_data_uri, f'{s3_bucket}/training_data/volatility', "volatility", "reg:squarederror")
    volatility_predictor = deploy_model(volatility_estimator, "volatility-forecast-endpoint")
    print("Volatility Forecasting Model deployed:", volatility_predictor.endpoint_name)

    anomaly_estimator = train_model(anomaly_data_uri, f'{s3_bucket}/training_data/anomaly', "anomaly", "binary:logistic")
    anomaly_predictor = deploy_model(anomaly_estimator, "anomaly-detection-endpoint")
    print("Anomaly Detection Model deployed:", anomaly_predictor.endpoint_name)



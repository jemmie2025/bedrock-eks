"""
Lambda function to process assets uploaded to S3
Logs the filename to CloudWatch Logs when a new file is uploaded
"""

import json
import logging
from urllib.parse import unquote_plus

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    """
    Lambda handler function triggered by S3 events
    
    Args:
        event: S3 event notification
        context: Lambda context object
        
    Returns:
        dict: Response with status code and message
    """
    
    try:
        # Parse S3 event
        for record in event['Records']:
            # Get bucket and object key
            bucket_name = record['s3']['bucket']['name']
            object_key = unquote_plus(record['s3']['object']['key'])
            object_size = record['s3']['object']['size']
            event_name = record['eventName']
            
            # Log the uploaded file information
            logger.info(f"Image received: {object_key}")
            logger.info(f"Bucket: {bucket_name}")
            logger.info(f"Size: {object_size} bytes")
            logger.info(f"Event: {event_name}")
            
            # Additional processing could be added here
            # For example: image resizing, validation, metadata extraction, etc.
            
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Asset processed successfully',
                'files_processed': len(event['Records'])
            })
        }
        
    except Exception as e:
        logger.error(f"Error processing S3 event: {str(e)}")
        logger.error(f"Event: {json.dumps(event)}")
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': 'Error processing asset',
                'error': str(e)
            })
        }
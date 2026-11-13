import json


def handler(event, context):
    response = {
        "backend": "lambda",
        "method": event.get("httpMethod"),
        "path": event.get("path"),
        "request_id": context.aws_request_id,
    }

    return {
        "statusCode": 200,
        "statusDescription": "200 OK",
        "isBase64Encoded": False,
        "headers": {"content-type": "application/json"},
        "body": json.dumps(response),
    }

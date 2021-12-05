import json
import urllib.parse
import boto3
import os

print('Loading function')

s3 = boto3.client('s3')


def lambda_handler(event, context):
    print("Received event: " + json.dumps(event, indent=2))

    # Get the object from the event and show its content type
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'], encoding='utf-8')
    try:
        response = s3.get_object(Bucket=bucket, Key=key)
        print("CONTENT TYPE: " + response['ContentType'])
        inputString = response['Body'].read().decode('utf-8')
        j = json.loads(inputString)
        print("BODY: " + inputString)
        print("NAME: " + j["name"])

        output = json.dumps({ "greeting": "I would like to say hello to " + j["name"] })
        output_filename = os.path.splitext(key)[0] + "-output.json"
        s3.put_object(Body=output, Bucket='mkns-20211204-terraform-s3-lambda-output', Key=output_filename, ACL='public-read')

        return response['ContentType']
    except Exception as e:
        print(e)
        print('Error getting object {} from bucket {}. Make sure they exist and your bucket is in the same region as this function.'.format(key, bucket))
        raise e

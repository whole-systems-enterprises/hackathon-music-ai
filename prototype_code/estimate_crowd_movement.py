#
# import required libraries
#
import boto3
import json
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import time

#
# user settings (for later movement to command line options and/or a config file).
#
job_tag = 'Job-001'
output_directory = '/home/emily/hackathon-music-ai/output'
min_ts = 1000 # milliseconds
interval = 5000
person_limit = 50
s3_bucket = 'wse-sagemaker-test'
movie_name = 'edm-crowd.mp4'
sns_topic_arn = 'arn:aws:sns:us-west-2:651928424815:CrowdMetrics'
role_arn = 'arn:aws:iam::651928424815:role/RekognitionRole'
wait_time = 10  # seconds

#
# start rekognition client
#
client = boto3.client('rekognition')

#
# start SNS client
#
client_sns = boto3.client('sns')

#
# Start AWS Rekognition analysis of video to identify locations and space taken up by human bodies
#
response = client.start_person_tracking(
    Video = {
        'S3Object' : {
            'Bucket' : s3_bucket,
            'Name' : movie_name,
        }
    },
    ClientRequestToken = '1',
    NotificationChannel = {
        'SNSTopicArn' : sns_topic_arn,
        'RoleArn' : role_arn,

    },
    JobTag = job_tag
)

#
# save JobId
#
with open(output_directory + '/' + job_tag + '.json', 'w') as f:
    json.dump(response, f, indent=4)

#
# test job status (I could not [yet] get this to work, so we are crudely waiting ten seconds).
#
time.sleep(wait_time)

#
# retreive JobId
#
with open(output_directory + '/' + job_tag + '.json') as f:
    response = json.load(f)
    
job_id = response['JobId']

#
# assemble the initial data structure for the crowd
#
crowd = []

response = client.get_person_tracking(
    JobId = job_id,
    MaxResults = 1000,
    SortBy = 'INDEX'
)

crowd.extend(response['Persons'])

on = False
if 'NextToken' in response:
    on = True
while on:
    NextToken = response['NextToken']
    response = client.get_person_tracking(
        JobId = job_id,
        MaxResults = 1000,
        SortBy = 'INDEX'
    )

    for person in response['Persons']:
        if person['Person']['Index'] >= person_limit:
            on = False

    if not 'NextToken' in response:
        on = False
    
    crowd.extend(response['Persons'])
    
#
# reorganize this data structure into a form easily converted into a DataFrame
#
crowd_reorganized = []
for person in crowd:
    ts = person['Timestamp']
    if ts < min_ts:
        continue
    
    person_id = person['Person']['Index']
    if 'BoundingBox' in person['Person']:
        height = person['Person']['BoundingBox']['Height']
        width = person['Person']['BoundingBox']['Width']
        crowd_reorganized.append(
            {
                'timestamp' : ts,
                'person_id' : person_id,
                'box_height' : height,
                'box_width' : width,
            }
        )

#
# build dataframe
#
df = pd.DataFrame(crowd_reorganized)
df['interval'] = [int(round(x)) for x in df['timestamp'] / interval]

#
# calculate standard dev of height per person per interval
#
df_std = df.groupby(['person_id', 'interval']).agg({'box_height' : ['std'], 'box_width' : ['std']})

#
# calculate mean of the individual's standard deviations, per interval
#
df_std_mean = df_std.groupby(['interval']).agg({('box_height', 'std') : ['mean'], ('box_width', 'std') : ['mean']})

#
# save results
#
df_std_mean.to_csv(output_directory + '/df_std_mean.csv', index=False)

#
# plot the vertical movement metric
#
y = df_std_mean[('box_height', 'std', 'mean')] - min(df_std_mean[('box_height', 'std', 'mean')])
max_y = max(y)
y = [x / max_y for x in y]
plt.figure(figsize=[10, 8])
plt.plot(df_std_mean.index, y)
plt.ylabel('Crowd Vertical Movement Metric', fontsize=14)
plt.xlabel('Five-Second Interval', fontsize=14)
plt.title('Crowd Vertical Movement Metric vs. Time', fontsize=20)
plt.savefig(output_directory + '/vertical_movement_metric_plot.png')
plt.close()

import boto3
import json
import pprint as pp
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

job_tag = 'Job-001'
analyze_video = False
min_ts = 1000 # milliseconds
interval = 5000
person_limit = 50

client = boto3.client('rekognition')


if analyze_video:

    response = client.start_person_tracking(
        Video = {
            'S3Object' : {
                'Bucket' : 'wse-sagemaker-test',
                'Name' : 'edm-crowd.mp4'
            }
        },
        ClientRequestToken = '1',
        NotificationChannel = {
            'SNSTopicArn' : 'arn:aws:sns:us-west-2:651928424815:CrowdMetrics',
            'RoleArn' : 'arn:aws:iam::651928424815:role/RekognitionRole'

        },
        JobTag = job_tag
    )
    
    #pp.pprint(response)

    with open('output/' + job_tag + '.json', 'w') as f:
        json.dump(response, f, indent=4)


with open('output/' + job_tag + '.json') as f:
    response = json.load(f)
    
job_id = response['JobId']

#print(job_id)


crowd = []


response = client.get_person_tracking(
    JobId = job_id,
    MaxResults = 1000,
    SortBy = 'INDEX'
)

crowd.extend(response['Persons'])
#print(len(crowd))


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
    
#print(len(crowd))
#pp.pprint(crowd)

#
# reorganize
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
# filter extreme values
#
idx_min = list(df['box_height']).index(max(df['box_height']))
idx_max = list(df['box_height']).index(min(df['box_height']))
#df_filtered = df.loc[not df['person_id'].isin([idx_min, idx_max])]

#
# standard dev of height per person per half-second
#
df_std = df.groupby(['person_id', 'interval']).agg({'box_height' : ['std'], 'box_width' : ['std']})

df_std_mean = df_std.groupby(['interval']).agg({('box_height', 'std') : ['mean'], ('box_width', 'std') : ['mean']})

print()
print(df_std_mean)
print()



#
y = df_std_mean[('box_height', 'std', 'mean')] - min(df_std_mean[('box_height', 'std', 'mean')])
max_y = max(y)
y = [x / max_y for x in y]
plt.figure(figsize=[10, 8])
plt.plot(df_std_mean.index, y)
plt.ylabel('Crowd Vertical Movement Metric', fontsize=14)
plt.xlabel('Five-Second Interval', fontsize=14)
plt.title('Crowd Vertical Movement Metric vs. Time', fontsize=20)
plt.savefig('/home/emily/Documents/vertical_movement_metric_plot.png')
plt.close()
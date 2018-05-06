import requests

import json
import pprint as pp

headers = {
    'Content-Type' : 'application/json',
}
data = {'data' : [[0.01, 0.02, 0.01, 0.02],[0.03, 0.04, 0.03, 0.04]]}
 
r = requests.post('http://localhost:8000/core/load_into_database/', data=json.dumps(data), headers=headers)

pp.pprint(r.json())

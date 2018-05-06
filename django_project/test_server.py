import requests

import json
import pprint as pp

headers = {
    'Content-Type' : 'application/json',
}
 
r = requests.get('http://localhost:8000/core/load_into_database/', headers=headers)

pp.pprint(r.text)

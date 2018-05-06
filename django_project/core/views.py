from django.shortcuts import render


# Create your views here.

from django.http import HttpRequest, HttpResponse
from django.views.decorators.csrf import csrf_exempt

import json
import datetime

from core.models import FaceLocation

def index(request):
    return HttpResponsce(json.dumps({}))

@csrf_exempt 
def load_into_database(request):
    if request.method == "POST":
        for entry in json.loads(request.body)['data']:
            face_location = FaceLocation(
                x_min = min(entry[0:2]),
                x_max = max(entry[0:2]),
                y_min = min(entry[2:4]),
                y_max = max(entry[2:4]),
                timestamp = datetime.datetime.now()
            )
            face_location.save()
        

    return HttpResponse(json.dumps({}))

from django.db import models

# Create your models here.

class MovementMetric(models.Model):
    height_mean_of_standard_deviations = models.FloatField()
    width_mean_of_standard_deviations = models.FloatField()
    timestamp = models.DateTimeField()


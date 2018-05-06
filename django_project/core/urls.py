from django.urls import path

from . import views

urlpatterns = [
    path('', views.index, name='index'),
    path('load_into_database/', views.load_into_database, name='load_into_database'),
]

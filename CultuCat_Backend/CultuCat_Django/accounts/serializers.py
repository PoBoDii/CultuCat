from rest_framework import serializers
from .models import Users

class UserProfileSerializer(serializers.ModelSerializer):
    email = serializers.EmailField(source='user.email', read_only=True)
    username = serializers.CharField(source='user.username', read_only=True)    
    class Meta:
        model = Users
        fields = ['username', 'email', 'profilephoto', 'telf', 'language', 'description', 'location']
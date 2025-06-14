from rest_framework import serializers
from .models import Review, LikedReview
from accounts.models import Users


class ReviewSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='username.user.username', read_only=True)
    likes_count = serializers.SerializerMethodField()
    dislikes_count = serializers.SerializerMethodField()
    user_liked = serializers.SerializerMethodField()
    
    class Meta:
        model = Review
        fields = ['username', 'id', 'event_id', 'rating', 'text', 'likes_count', 'dislikes_count', 'user_liked']
        read_only_fields = ['username', 'id', 'event_id']  # Una review es personal e intransferible (tanto del usuario como del evento)
    
    def get_likes_count(self, obj):
        # Contar likes para esta review (username es el autor de la reseña)
        return LikedReview.objects.filter(event_id=obj.event_id, username=obj.username, is_like=True).count()
    
    def get_dislikes_count(self, obj):
        # Contar dislikes para esta review (username es el autor de la reseña)
        return LikedReview.objects.filter(event_id=obj.event_id, username=obj.username, is_like=False).count()
        
    def get_user_liked(self, obj):
        # Verificar si el usuario actual ha dado like/dislike (user_liked es quien da like)
        request = self.context.get('request')
        if request and hasattr(request, 'user') and request.user.is_authenticated:
            try:
                # Obtener el usuario actual
                current_user = Users.objects.get(user=request.user)
                
                # Buscar un like/dislike donde el usuario actual es quien dio like
                like = LikedReview.objects.get(
                    event_id=obj.event_id, 
                    username=obj.username,
                    user_liked=current_user
                )
                return like.is_like  # True para like, False para dislike
            except (LikedReview.DoesNotExist, Users.DoesNotExist):
                return None  # El usuario no ha dado ni like ni dislike
        return None


class LikedReviewSerializer(serializers.ModelSerializer):
    class Meta:
        model = LikedReview
        fields = '__all__'
from rest_framework import serializers

from .models import DailyReview


class DailyReviewSerializer(serializers.ModelSerializer):
    class Meta:
        model = DailyReview
        fields = [
            "id",
            "date",
            "productivity_rating",
            "win_of_the_day",
            "is_shutdown",
            "shutdown_at",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]

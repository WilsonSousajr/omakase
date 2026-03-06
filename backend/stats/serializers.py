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

    def validate(self, data):
        request = self.context.get("request")
        if request and not self.instance:
            date = data.get("date")
            if date and DailyReview.objects.filter(
                user=request.user, date=date
            ).exists():
                raise serializers.ValidationError(
                    {"date": "A review for this date already exists."}
                )
        return data

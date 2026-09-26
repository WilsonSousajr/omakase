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
            "energy",
            "is_shutdown",
            "shutdown_at",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "shutdown_at", "created_at", "updated_at"]

    def validate_energy(self, value: int | None) -> int | None:
        # Invariant 3: a 400 here, before the check constraint can 500.
        if value is not None and not 1 <= value <= 3:
            raise serializers.ValidationError(f"energy {value} is not 1, 2 or 3")
        return value

    def validate(self, data):
        request = self.context.get("request")
        if request and self.instance:
            # Reject date changes on update to prevent unique constraint 500
            if "date" in data and data["date"] != self.instance.date:
                raise serializers.ValidationError({"date": "Cannot change the date of an existing review."})
        elif request and not self.instance:
            date = data.get("date")
            if date and DailyReview.objects.filter(user=request.user, date=date).exists():
                raise serializers.ValidationError({"date": "A review for this date already exists."})
        return data

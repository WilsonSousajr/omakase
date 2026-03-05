from rest_framework import serializers

from .models import Discipline, Semester, StudyBlock


class SemesterSerializer(serializers.ModelSerializer):
    discipline_count = serializers.IntegerField(read_only=True, default=0)

    class Meta:
        model = Semester
        fields = [
            "id", "name", "institution", "start_date", "end_date",
            "status", "discipline_count", "created_at", "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]

    def validate(self, data):
        start = data.get("start_date", getattr(self.instance, "start_date", None))
        end = data.get("end_date", getattr(self.instance, "end_date", None))
        if start and end and end <= start:
            raise serializers.ValidationError("end_date must be after start_date.")
        return data


class DisciplineSerializer(serializers.ModelSerializer):
    study_block_count = serializers.IntegerField(read_only=True, default=0)

    class Meta:
        model = Discipline
        fields = [
            "id", "semester", "name", "code", "professor", "color",
            "credits", "target_grade", "status", "study_block_count",
            "created_at", "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]


class StudyBlockSerializer(serializers.ModelSerializer):
    class Meta:
        model = StudyBlock
        fields = [
            "id", "discipline", "title", "block_type", "priority", "status",
            "notes", "estimated_minutes", "scheduled_date", "due_date",
            "is_completed", "completed_at", "created_at", "updated_at",
        ]
        read_only_fields = ["id", "completed_at", "created_at", "updated_at"]

from rest_framework import serializers

from .models import ClassSchedule, Discipline, Semester, StudyBlock


class SemesterSerializer(serializers.ModelSerializer):
    discipline_count = serializers.IntegerField(read_only=True, default=0)

    class Meta:
        model = Semester
        fields = [
            "id",
            "name",
            "institution",
            "start_date",
            "end_date",
            "status",
            "discipline_count",
            "created_at",
            "updated_at",
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
            "id",
            "semester",
            "name",
            "code",
            "professor",
            "color",
            "credits",
            "target_grade",
            "status",
            "study_block_count",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]


class StudyBlockSerializer(serializers.ModelSerializer):
    actual_minutes = serializers.SerializerMethodField()

    def get_actual_minutes(self, obj):
        total = 0
        for tb in obj.time_blocks.all():
            start = tb.start_time.hour * 60 + tb.start_time.minute
            end = tb.end_time.hour * 60 + tb.end_time.minute
            total += max(0, end - start)
        return total

    class Meta:
        model = StudyBlock
        fields = [
            "id",
            "discipline",
            "title",
            "block_type",
            "priority",
            "status",
            "notes",
            "estimated_minutes",
            "actual_minutes",
            "scheduled_date",
            "due_date",
            "is_completed",
            "completed_at",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "completed_at", "created_at", "updated_at"]


class ClassScheduleSerializer(serializers.ModelSerializer):
    class Meta:
        model = ClassSchedule
        fields = [
            "id",
            "discipline",
            "day_of_week",
            "start_time",
            "end_time",
            "class_type",
            "location",
            "is_active",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]

    def validate(self, data):
        start = data.get("start_time", getattr(self.instance, "start_time", None))
        end = data.get("end_time", getattr(self.instance, "end_time", None))
        if start and end and end <= start:
            raise serializers.ValidationError("end_time must be after start_time.")
        return data


class ClassOccurrenceSerializer(serializers.Serializer):
    id = serializers.CharField()
    class_schedule_id = serializers.UUIDField()
    discipline_name = serializers.CharField()
    discipline_color = serializers.CharField()
    class_type = serializers.CharField()
    location = serializers.CharField()
    date = serializers.DateField()
    start_time = serializers.TimeField()
    end_time = serializers.TimeField()

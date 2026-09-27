from rest_framework import serializers

from .constants import MAX_ROTATION_WEEKS
from .models import ClassSchedule, Discipline, Semester, StudyBlock


def _highest_week_in_use(semester: Semester) -> int:
    """The highest rotation week any of the semester's class schedules runs in, or 0."""
    weeks_on = ClassSchedule.objects.filter(discipline__semester=semester).values_list("rotation_weeks_on", flat=True)
    return max((week for weeks in weeks_on for week in weeks), default=0)


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
            "rotation_weeks",
            "rotation_anchor",
            "discipline_count",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]

    def validate_rotation_weeks(self, value: int) -> int:
        if not 1 <= value <= MAX_ROTATION_WEEKS:
            raise serializers.ValidationError(f"rotation_weeks {value} is not in 1-{MAX_ROTATION_WEEKS}.")
        in_use = _highest_week_in_use(self.instance) if self.instance else 0
        if value < in_use:
            raise serializers.ValidationError(
                f"rotation_weeks {value} is below week {in_use}, which a class schedule runs in."
            )
        return value

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
            "rotation_weeks_on",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]

    def validate_rotation_weeks_on(self, value: object) -> list[int]:
        # bool is an int in Python, and a JSON true is not a week number.
        if not isinstance(value, list) or not all(type(week) is int for week in value):
            raise serializers.ValidationError(
                f"rotation_weeks_on {value!r} is not a list of week numbers, e.g. [1, 3]."
            )
        return sorted(set(value))

    def validate(self, data):
        start = data.get("start_time", getattr(self.instance, "start_time", None))
        end = data.get("end_time", getattr(self.instance, "end_time", None))
        if start and end and end <= start:
            raise serializers.ValidationError("end_time must be after start_time.")
        self._check_weeks_fit_rotation(data)
        return data

    def _check_weeks_fit_rotation(self, data: dict) -> None:
        discipline = data.get("discipline", getattr(self.instance, "discipline", None))
        weeks_on = data.get("rotation_weeks_on", getattr(self.instance, "rotation_weeks_on", []))
        if discipline is None:
            return
        rotation = discipline.semester.rotation_weeks
        outside = [week for week in weeks_on if not 1 <= week <= rotation]
        if outside:
            raise serializers.ValidationError(
                {"rotation_weeks_on": f"week {outside[0]} is not in 1-{rotation}, the semester's rotation."}
            )


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
    week = serializers.IntegerField()
    is_cancelled = serializers.BooleanField()


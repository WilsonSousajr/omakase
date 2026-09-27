from rest_framework import serializers

from .models import (
    KanbanStatusChoices,
    Project,
    RecurrenceFreqChoices,
    Subtask,
    Tag,
    Task,
    TaskRecurrence,
    TimeBlock,
    Workspace,
)


class WorkspaceSerializer(serializers.ModelSerializer):
    project_count = serializers.IntegerField(read_only=True, default=0)

    class Meta:
        model = Workspace
        fields = ["id", "name", "color", "project_count", "created_at", "updated_at"]
        read_only_fields = ["id", "created_at", "updated_at"]


class ProjectSerializer(serializers.ModelSerializer):
    task_count = serializers.IntegerField(read_only=True, default=0)

    class Meta:
        model = Project
        fields = [
            "id",
            "workspace",
            "name",
            "description",
            "color",
            "status",
            "due_date",
            "task_count",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]


class TagSerializer(serializers.ModelSerializer):
    class Meta:
        model = Tag
        fields = ["id", "name", "color", "area", "created_at"]
        read_only_fields = ["id", "created_at"]


class TimeBlockSerializer(serializers.ModelSerializer):
    class Meta:
        model = TimeBlock
        fields = [
            "id",
            "task",
            "study_block",
            "date",
            "start_time",
            "end_time",
            "notes",
            "session_rating",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]

    def validate(self, data):
        start = data.get("start_time", getattr(self.instance, "start_time", None))
        end = data.get("end_time", getattr(self.instance, "end_time", None))
        if start and end and end <= start:
            raise serializers.ValidationError("end_time must be after start_time.")

        task = data.get("task", getattr(self.instance, "task", None))
        study_block = data.get("study_block", getattr(self.instance, "study_block", None))
        if not task and not study_block:
            raise serializers.ValidationError("Either task or study_block must be provided.")
        if task and study_block:
            raise serializers.ValidationError("Cannot set both task and study_block.")
        return data


class SubtaskSerializer(serializers.ModelSerializer):
    class Meta:
        model = Subtask
        fields = ["id", "title", "is_completed", "order", "created_at"]
        read_only_fields = ["id", "created_at"]


class TaskRecurrenceSerializer(serializers.ModelSerializer):
    """A series' rule (#124). A PUT replaces it whole, so it is validated whole.

    >>> TaskRecurrenceSerializer(data={"freq": "weekly", "weekdays": [0, 2], "starts_on": "2026-03-02"})
    """

    interval = serializers.IntegerField(default=1)
    weekdays = serializers.JSONField(default=list)

    class Meta:
        model = TaskRecurrence
        fields = ["freq", "interval", "weekdays", "starts_on", "until"]
        extra_kwargs = {
            "freq": {
                "error_messages": {"invalid_choice": '"{input}" is not a freq; expected daily, weekly or monthly.'}
            }
        }

    def validate_interval(self, value: int) -> int:
        if not 1 <= value <= 30:
            raise serializers.ValidationError(
                f"interval {value} is outside 1-30 (a whole number of days, weeks or months)."
            )
        return value

    def validate_weekdays(self, value: object) -> list[int]:
        if not isinstance(value, list) or not all(_is_weekday(day) for day in value):
            raise serializers.ValidationError(
                f"weekdays {value!r} must be a list of integers 0 (Monday) to 6 (Sunday)."
            )
        return sorted(set(value))

    def validate(self, attrs: dict) -> dict:
        weekdays, freq = attrs.get("weekdays", []), attrs["freq"]
        if weekdays and freq != RecurrenceFreqChoices.WEEKLY:
            raise serializers.ValidationError(
                {"weekdays": f"weekdays {weekdays!r} apply only to freq 'weekly', not {freq!r}."}
            )
        until, starts_on = attrs.get("until"), attrs["starts_on"]
        if until is not None and until < starts_on:
            raise serializers.ValidationError(
                {
                    "until": f"until {until.isoformat()} is before starts_on {starts_on.isoformat()}; "
                    "expected until >= starts_on."
                }
            )
        return attrs


def _is_weekday(value: object) -> bool:
    # bool is an int in Python; True is not a Tuesday.
    return isinstance(value, int) and not isinstance(value, bool) and 0 <= value <= 6


class TaskListSerializer(serializers.ModelSerializer):
    tags = TagSerializer(many=True, read_only=True)
    tag_ids = serializers.PrimaryKeyRelatedField(
        many=True, queryset=Tag.objects.all(), write_only=True, source="tags", required=False
    )
    actual_minutes = serializers.SerializerMethodField()
    is_virtual = serializers.SerializerMethodField()
    recurrence = serializers.SerializerMethodField()

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        request = self.context.get("request")
        if request and hasattr(request, "user"):
            self.fields["tag_ids"].child_relation.queryset = Tag.objects.filter(user=request.user)

    def get_actual_minutes(self, obj):
        total = 0
        for tb in obj.time_blocks.all():
            start = tb.start_time.hour * 60 + tb.start_time.minute
            end = tb.end_time.hour * 60 + tb.end_time.minute
            total += max(0, end - start)
        return total

    def get_is_virtual(self, obj: Task) -> bool:
        # A row is concrete by definition; virtual occurrences are never rows (#124).
        return False

    def get_recurrence(self, obj: Task) -> dict | None:
        rule = obj.series_rule
        return TaskRecurrenceSerializer(rule).data if rule else None

    class Meta:
        model = Task
        fields = [
            "id",
            "title",
            "description",
            "priority",
            "area",
            "kanban_status",
            "project",
            "discipline",
            "tags",
            "tag_ids",
            "scheduled_date",
            "due_date",
            "remind_at",
            "estimated_minutes",
            "actual_minutes",
            "kanban_order",
            "is_completed",
            "completed_at",
            "series",
            "occurrence_date",
            "is_skipped",
            "is_virtual",
            "recurrence",
            "created_at",
            "updated_at",
        ]
        # The series fields are written only by the occurrence and recurrence
        # endpoints, which keep them consistent with the rule (#124).
        read_only_fields = [
            "id",
            "completed_at",
            "series",
            "occurrence_date",
            "is_skipped",
            "created_at",
            "updated_at",
        ]


class TaskDayListSerializer(TaskListSerializer):
    """A day's tasks with their subtasks, so Focus needs one request (M3.1 spec §1.4)."""

    subtasks = SubtaskSerializer(many=True, read_only=True)

    class Meta(TaskListSerializer.Meta):
        fields = TaskListSerializer.Meta.fields + ["subtasks"]


class TaskOccurrenceSerializer(TaskDayListSerializer):
    """The materialize PUT's body (#124): any task field, plus is_skipped, which only an occurrence has."""

    class Meta(TaskDayListSerializer.Meta):
        read_only_fields = [name for name in TaskListSerializer.Meta.read_only_fields if name != "is_skipped"]


class VirtualOccurrenceSerializer(serializers.BaseSerializer):
    """A computed occurrence, shaped as TaskDayListSerializer shapes a row (#124, M8 design §2).

    It has no id until something writes to it (PUT tasks/<series>/occurrences/<date>/),
    and nothing of its own: no subtasks, blocks, completion or reminder yet.

    >>> VirtualOccurrenceSerializer(VirtualOccurrence(template, day)).data["id"] is None
    True
    """

    def to_representation(self, instance) -> dict:
        data = TaskDayListSerializer(instance.template, context=self.context).data
        day = instance.day.isoformat()
        data.update(
            {
                "id": None,
                "series": instance.template.pk,
                "occurrence_date": day,
                "scheduled_date": day,
                "is_virtual": True,
                "subtasks": [],
                "actual_minutes": 0,
                "is_completed": False,
                "completed_at": None,
                "kanban_status": KanbanStatusChoices.TODO,
                "due_date": None,
                "remind_at": None,
                "is_skipped": False,
            }
        )
        return data


def day_items_data(items: list, context: dict) -> list[dict]:
    """Serialize tasks.services.day_items: rows as TaskDayListSerializer, the rest as virtual.

    >>> day_items_data(day_items(user, day, day), {"request": request})
    """
    return [
        (TaskDayListSerializer if isinstance(item, Task) else VirtualOccurrenceSerializer)(item, context=context).data
        for item in items
    ]


class TaskSerializer(TaskListSerializer):
    time_blocks = TimeBlockSerializer(many=True, read_only=True)
    subtasks = SubtaskSerializer(many=True, read_only=True)

    class Meta(TaskListSerializer.Meta):
        fields = TaskListSerializer.Meta.fields + ["notes", "time_blocks", "subtasks"]


class TaskReorderSerializer(serializers.Serializer):
    id = serializers.UUIDField()
    kanban_order = serializers.IntegerField()
    kanban_status = serializers.ChoiceField(choices=["todo", "in_progress", "done"])

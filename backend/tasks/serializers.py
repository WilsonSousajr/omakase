from rest_framework import serializers

from .models import Project, Subtask, Tag, Task, TimeBlock, Workspace


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
        fields = ["id", "task", "study_block", "date", "start_time", "end_time", "notes", "created_at", "updated_at"]
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


class TaskListSerializer(serializers.ModelSerializer):
    tags = TagSerializer(many=True, read_only=True)
    tag_ids = serializers.PrimaryKeyRelatedField(
        many=True, queryset=Tag.objects.all(), write_only=True, source="tags", required=False
    )

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        request = self.context.get("request")
        if request and hasattr(request, "user"):
            self.fields["tag_ids"].child_relation.queryset = Tag.objects.filter(user=request.user)

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
            "estimated_minutes",
            "kanban_order",
            "is_completed",
            "completed_at",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "completed_at", "created_at", "updated_at"]


class TaskSerializer(TaskListSerializer):
    time_blocks = TimeBlockSerializer(many=True, read_only=True)
    subtasks = SubtaskSerializer(many=True, read_only=True)

    class Meta(TaskListSerializer.Meta):
        fields = TaskListSerializer.Meta.fields + ["notes", "time_blocks", "subtasks"]


class TaskReorderSerializer(serializers.Serializer):
    id = serializers.UUIDField()
    kanban_order = serializers.IntegerField()
    kanban_status = serializers.ChoiceField(choices=["todo", "in_progress", "done"])

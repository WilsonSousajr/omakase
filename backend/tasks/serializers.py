from rest_framework import serializers

from .models import Tag, Task, TimeBlock


class TagSerializer(serializers.ModelSerializer):
    class Meta:
        model = Tag
        fields = ["id", "name", "color", "area", "created_at"]
        read_only_fields = ["id", "created_at"]


class TimeBlockSerializer(serializers.ModelSerializer):
    class Meta:
        model = TimeBlock
        fields = ["id", "task", "date", "start_time", "end_time", "created_at", "updated_at"]
        read_only_fields = ["id", "created_at", "updated_at"]


class TaskListSerializer(serializers.ModelSerializer):
    tags = TagSerializer(many=True, read_only=True)
    tag_ids = serializers.PrimaryKeyRelatedField(
        many=True, queryset=Tag.objects.all(), write_only=True, source="tags", required=False
    )

    class Meta:
        model = Task
        fields = [
            "id", "title", "description", "priority", "area", "kanban_status",
            "tags", "tag_ids", "scheduled_date", "due_date", "estimated_minutes",
            "kanban_order", "is_completed", "completed_at", "created_at", "updated_at",
        ]
        read_only_fields = ["id", "completed_at", "created_at", "updated_at"]


class TaskSerializer(TaskListSerializer):
    time_blocks = TimeBlockSerializer(many=True, read_only=True)

    class Meta(TaskListSerializer.Meta):
        fields = TaskListSerializer.Meta.fields + ["notes", "time_blocks"]


class TaskReorderSerializer(serializers.Serializer):
    id = serializers.UUIDField()
    kanban_order = serializers.IntegerField()
    kanban_status = serializers.ChoiceField(
        choices=["todo", "in_progress", "done"]
    )

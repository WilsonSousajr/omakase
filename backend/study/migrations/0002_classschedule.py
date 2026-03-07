import django.db.models.deletion
import uuid
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("study", "0001_initial"),
    ]

    operations = [
        migrations.CreateModel(
            name="ClassSchedule",
            fields=[
                (
                    "id",
                    models.UUIDField(
                        default=uuid.uuid4,
                        editable=False,
                        primary_key=True,
                        serialize=False,
                    ),
                ),
                (
                    "day_of_week",
                    models.IntegerField(
                        choices=[
                            (0, "Monday"),
                            (1, "Tuesday"),
                            (2, "Wednesday"),
                            (3, "Thursday"),
                            (4, "Friday"),
                            (5, "Saturday"),
                            (6, "Sunday"),
                        ]
                    ),
                ),
                ("start_time", models.TimeField()),
                ("end_time", models.TimeField()),
                (
                    "class_type",
                    models.CharField(
                        choices=[
                            ("lecture", "Lecture"),
                            ("lab", "Lab"),
                            ("tutorial", "Tutorial"),
                            ("seminar", "Seminar"),
                        ],
                        default="lecture",
                        max_length=20,
                    ),
                ),
                ("location", models.CharField(blank=True, default="", max_length=300)),
                ("is_active", models.BooleanField(default=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                (
                    "discipline",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="class_schedules",
                        to="study.discipline",
                    ),
                ),
            ],
            options={
                "ordering": ["day_of_week", "start_time"],
            },
        ),
        migrations.AddConstraint(
            model_name="classschedule",
            constraint=models.CheckConstraint(
                check=models.Q(("end_time__gt", models.F("start_time"))),
                name="class_end_after_start",
            ),
        ),
        migrations.AddConstraint(
            model_name="classschedule",
            constraint=models.CheckConstraint(
                check=models.Q(("day_of_week__gte", 0), ("day_of_week__lte", 6)),
                name="class_valid_day_of_week",
            ),
        ),
    ]

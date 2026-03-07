import django.core.validators
import django.db.models.deletion
import uuid
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="Semester",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("name", models.CharField(max_length=200)),
                ("institution", models.CharField(blank=True, default="", max_length=200)),
                ("start_date", models.DateField()),
                ("end_date", models.DateField()),
                ("status", models.CharField(
                    choices=[("active", "Active"), ("completed", "Completed"), ("archived", "Archived")],
                    default="active", max_length=20,
                )),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("user", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="semesters",
                    to=settings.AUTH_USER_MODEL,
                )),
            ],
            options={
                "ordering": ["-start_date"],
            },
        ),
        migrations.AddConstraint(
            model_name="semester",
            constraint=models.CheckConstraint(
                check=models.Q(end_date__gt=models.F("start_date")),
                name="semester_end_after_start",
            ),
        ),
        migrations.CreateModel(
            name="Discipline",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("name", models.CharField(max_length=200)),
                ("code", models.CharField(blank=True, default="", max_length=20)),
                ("professor", models.CharField(blank=True, default="", max_length=200)),
                ("color", models.CharField(
                    default="#a3a3a3", max_length=7,
                    validators=[django.core.validators.RegexValidator(
                        message="Color must be a valid hex color (e.g. #ff0000)",
                        regex="^#[0-9a-fA-F]{6}$",
                    )],
                )),
                ("credits", models.PositiveIntegerField(blank=True, null=True)),
                ("target_grade", models.DecimalField(blank=True, decimal_places=1, max_digits=4, null=True)),
                ("status", models.CharField(
                    choices=[("active", "Active"), ("completed", "Completed"), ("dropped", "Dropped")],
                    default="active", max_length=20,
                )),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("semester", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="disciplines",
                    to="study.semester",
                )),
            ],
            options={
                "ordering": ["name"],
            },
        ),
        migrations.CreateModel(
            name="StudyBlock",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("title", models.CharField(max_length=500)),
                ("block_type", models.CharField(
                    choices=[
                        ("theory", "Theory"), ("exercises", "Exercises"), ("review", "Review"),
                        ("assignment", "Assignment"), ("exam_prep", "Exam Prep"),
                        ("lab", "Lab"), ("reading", "Reading"),
                    ],
                    default="theory", max_length=20,
                )),
                ("priority", models.CharField(
                    choices=[("low", "Low"), ("medium", "Medium"), ("high", "High"), ("urgent", "Urgent")],
                    default="medium", max_length=10,
                )),
                ("status", models.CharField(
                    choices=[
                        ("planned", "Planned"), ("in_progress", "In Progress"),
                        ("completed", "Completed"), ("skipped", "Skipped"),
                    ],
                    default="planned", max_length=20,
                )),
                ("notes", models.TextField(blank=True, default="")),
                ("estimated_minutes", models.PositiveIntegerField(blank=True, null=True)),
                ("scheduled_date", models.DateField(blank=True, db_index=True, null=True)),
                ("due_date", models.DateField(blank=True, null=True)),
                ("is_completed", models.BooleanField(db_index=True, default=False)),
                ("completed_at", models.DateTimeField(blank=True, null=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("discipline", models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name="study_blocks",
                    to="study.discipline",
                )),
            ],
            options={
                "ordering": ["-created_at"],
            },
        ),
    ]

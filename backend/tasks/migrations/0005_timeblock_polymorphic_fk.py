import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("tasks", "0004_add_workspace_project_models"),
        ("study", "0001_initial"),
    ]

    operations = [
        # Make task nullable (was CASCADE, now SET_NULL)
        migrations.AlterField(
            model_name="timeblock",
            name="task",
            field=models.ForeignKey(
                blank=True, null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="time_blocks",
                to="tasks.task",
            ),
        ),
        # Add study_block FK
        migrations.AddField(
            model_name="timeblock",
            name="study_block",
            field=models.ForeignKey(
                blank=True, null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="time_blocks",
                to="study.studyblock",
            ),
        ),
        # Add constraint: at least one of task/study_block must be set
        migrations.AddConstraint(
            model_name="timeblock",
            constraint=models.CheckConstraint(
                check=models.Q(task__isnull=False) | models.Q(study_block__isnull=False),
                name="timeblock_has_task_or_study_block",
            ),
        ),
    ]

import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("tasks", "0005_timeblock_polymorphic_fk"),
        ("study", "0002_classschedule"),
    ]

    operations = [
        migrations.AddField(
            model_name="task",
            name="discipline",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="tasks",
                to="study.discipline",
            ),
        ),
    ]

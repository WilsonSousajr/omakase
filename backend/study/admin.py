from django.contrib import admin

from .models import ClassSchedule, Discipline, Semester, StudyBlock

admin.site.register(Semester)
admin.site.register(Discipline)
admin.site.register(StudyBlock)
admin.site.register(ClassSchedule)

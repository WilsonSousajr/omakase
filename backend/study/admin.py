from django.contrib import admin

from .models import Discipline, Semester, StudyBlock

admin.site.register(Semester)
admin.site.register(Discipline)
admin.site.register(StudyBlock)

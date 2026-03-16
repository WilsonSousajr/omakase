import re

from django.contrib.auth.models import User
from django.db import transaction
from rest_framework import serializers

from accounts.models import UserProfile


class GoogleLoginSerializer(serializers.Serializer):
    credential = serializers.CharField()


class UserSerializer(serializers.ModelSerializer):
    avatar_color = serializers.CharField(source="profile.avatar_color", read_only=True)
    first_name = serializers.CharField(read_only=True)
    last_name = serializers.CharField(read_only=True)

    class Meta:
        model = User
        fields = [
            "id",
            "username",
            "email",
            "first_name",
            "last_name",
            "avatar_color",
            "date_joined",
        ]
        read_only_fields = fields


class UpdateProfileSerializer(serializers.Serializer):
    first_name = serializers.CharField(max_length=150, required=False, allow_blank=True)
    last_name = serializers.CharField(max_length=150, required=False, allow_blank=True)
    email = serializers.EmailField(required=False)
    avatar_color = serializers.CharField(max_length=7, required=False)

    def validate_email(self, value):
        user = self.context["request"].user
        if User.objects.filter(email=value).exclude(pk=user.pk).exists():
            raise serializers.ValidationError("A user with this email already exists.")
        return value

    def validate_avatar_color(self, value):
        if not re.match(r"^#[0-9a-fA-F]{6}$", value):
            raise serializers.ValidationError("Color must be a valid hex color (e.g. #ff0000).")
        return value

    def save(self, **kwargs):
        user = self.context["request"].user
        with transaction.atomic():
            if "first_name" in self.validated_data:
                user.first_name = self.validated_data["first_name"]
            if "last_name" in self.validated_data:
                user.last_name = self.validated_data["last_name"]
            if "email" in self.validated_data:
                user.email = self.validated_data["email"]
            user.save()

            if "avatar_color" in self.validated_data:
                user.profile.avatar_color = self.validated_data["avatar_color"]
                user.profile.save()

        return user



class UserProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserProfile
        fields = [
            "timezone",
            "week_starts_on",
            "pomodoro_work_minutes",
            "pomodoro_short_break_minutes",
            "pomodoro_long_break_minutes",
            "pomodoros_before_long_break",
            "daily_work_goal_hours",
            "daily_study_goal_hours",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["created_at", "updated_at"]

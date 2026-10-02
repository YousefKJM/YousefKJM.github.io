---
title: "A Production-Shaped Django REST API in 10 Steps"
excerpt: "From empty folder to an authenticated, paginated, filterable REST API with Django REST Framework — ten steps, each one a command or a short file, in the order you actually need them."
---

Django was the backend behind several of my university projects (including Mon9et, a Quran recitation checker). Django REST Framework (DRF) turns it into an API server with very little code. Here's the path from zero to something shaped like production.

## How a request flows through DRF

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 140" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Request flow: URL router to ViewSet, which checks permissions, uses a serializer to validate and convert, and reads or writes through the model to the database">
  <defs><marker id="dj-arr" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--text-muted)"/></marker></defs>
  <g style="font-size:12px;">
    <rect x="5" y="40" width="95" height="56" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="22" y="64" font-weight="700" fill="var(--text)">Router</text>
    <text x="22" y="82" fill="var(--text-muted)">urls.py</text>
    <rect x="130" y="40" width="110" height="56" rx="8" fill="var(--bg-elevated-2)" stroke="var(--accent)" stroke-width="2"/>
    <text x="146" y="64" font-weight="700" fill="var(--accent)">ViewSet</text>
    <text x="146" y="82" fill="var(--text-muted)">auth · perms</text>
    <rect x="270" y="40" width="120" height="56" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="286" y="64" font-weight="700" fill="var(--text)">Serializer</text>
    <text x="286" y="82" fill="var(--text-muted)">validate · JSON</text>
    <rect x="420" y="40" width="95" height="56" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="440" y="64" font-weight="700" fill="var(--text)">Model</text>
    <text x="440" y="82" fill="var(--text-muted)">ORM</text>
    <rect x="545" y="40" width="90" height="56" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="568" y="72" font-weight="700" fill="var(--text)">DB</text>
    <line x1="100" y1="68" x2="126" y2="68" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#dj-arr)"/>
    <line x1="240" y1="68" x2="266" y2="68" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#dj-arr)"/>
    <line x1="390" y1="68" x2="416" y2="68" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#dj-arr)"/>
    <line x1="515" y1="68" x2="541" y2="68" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#dj-arr)"/>
  </g>
</svg>
</div>

## Step 1 — Isolated environment

```bash
python -m venv venv && source venv/bin/activate
pip install django djangorestframework django-filter
pip freeze > requirements.txt
```

## Step 2 — Project and app

```bash
django-admin startproject core .
python manage.py startapp projects
```

Add to `core/settings.py`:

```python
INSTALLED_APPS += ["rest_framework", "django_filters", "projects"]
```

## Step 3 — The model

```python
# projects/models.py
from django.conf import settings
from django.db import models

class Project(models.Model):
    owner       = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="projects")
    name        = models.CharField(max_length=120)
    description = models.TextField(blank=True)
    tech        = models.CharField(max_length=200, help_text="comma-separated")
    is_public   = models.BooleanField(default=True)
    created_at  = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return self.name
```

## Step 4 — Migrate

```bash
python manage.py makemigrations
python manage.py migrate
python manage.py createsuperuser
```

## Step 5 — The serializer (validation lives here)

```python
# projects/serializers.py
from rest_framework import serializers
from .models import Project

class ProjectSerializer(serializers.ModelSerializer):
    owner = serializers.ReadOnlyField(source="owner.username")   # never trust client for this

    class Meta:
        model  = Project
        fields = ["id", "owner", "name", "description", "tech", "is_public", "created_at"]

    def validate_name(self, value):
        if len(value.strip()) < 3:
            raise serializers.ValidationError("Name must be at least 3 characters.")
        return value.strip()
```

## Step 6 — A permission class

```python
# projects/permissions.py
from rest_framework import permissions

class IsOwnerOrReadOnly(permissions.BasePermission):
    def has_object_permission(self, request, view, obj):
        if request.method in permissions.SAFE_METHODS:      # GET, HEAD, OPTIONS
            return True
        return obj.owner == request.user
```

## Step 7 — The ViewSet (full CRUD in ~10 lines)

```python
# projects/views.py
from rest_framework import viewsets, permissions
from .models import Project
from .serializers import ProjectSerializer
from .permissions import IsOwnerOrReadOnly

class ProjectViewSet(viewsets.ModelViewSet):
    serializer_class   = ProjectSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly, IsOwnerOrReadOnly]
    filterset_fields   = ["is_public", "owner__username"]
    search_fields      = ["name", "description", "tech"]
    ordering_fields    = ["created_at", "name"]

    def get_queryset(self):
        return Project.objects.select_related("owner")      # avoids N+1 queries on owner

    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)
```

## Step 8 — Routes

```python
# core/urls.py
from django.contrib import admin
from django.urls import include, path
from rest_framework.routers import DefaultRouter
from projects.views import ProjectViewSet

router = DefaultRouter()
router.register(r"projects", ProjectViewSet, basename="project")

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/", include(router.urls)),
    path("api-auth/", include("rest_framework.urls")),
]
```

That single `register` call gives you:

| Method | URL | Action |
|---|---|---|
| GET | `/api/projects/` | list (paginated, filterable) |
| POST | `/api/projects/` | create |
| GET | `/api/projects/{id}/` | retrieve |
| PUT / PATCH | `/api/projects/{id}/` | update |
| DELETE | `/api/projects/{id}/` | destroy |

## Step 9 — Global defaults: pagination, filtering, auth, throttling

```python
# core/settings.py
REST_FRAMEWORK = {
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 20,
    "DEFAULT_FILTER_BACKENDS": [
        "django_filters.rest_framework.DjangoFilterBackend",
        "rest_framework.filters.SearchFilter",
        "rest_framework.filters.OrderingFilter",
    ],
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "rest_framework.authentication.SessionAuthentication",
        "rest_framework.authentication.TokenAuthentication",
    ],
    "DEFAULT_THROTTLE_CLASSES": ["rest_framework.throttling.AnonRateThrottle",
                                 "rest_framework.throttling.UserRateThrottle"],
    "DEFAULT_THROTTLE_RATES": {"anon": "60/min", "user": "600/min"},
}
```

Now `GET /api/projects/?search=vue&ordering=-created_at&page=2` just works.

## Step 10 — Test it

```python
# projects/tests.py
from django.contrib.auth.models import User
from rest_framework.test import APITestCase

class ProjectAPITests(APITestCase):
    def setUp(self):
        self.alice = User.objects.create_user("alice", password="pw")
        self.bob   = User.objects.create_user("bob", password="pw")

    def test_owner_is_set_from_request_not_payload(self):
        self.client.force_authenticate(self.alice)
        r = self.client.post("/api/projects/", {"name": "Portfolio", "tech": "Vue", "owner": "bob"})
        self.assertEqual(r.status_code, 201)
        self.assertEqual(r.data["owner"], "alice")

    def test_non_owner_cannot_delete(self):
        self.client.force_authenticate(self.alice)
        pid = self.client.post("/api/projects/", {"name": "Mine", "tech": "Django"}).data["id"]
        self.client.force_authenticate(self.bob)
        self.assertEqual(self.client.delete(f"/api/projects/{pid}/").status_code, 403)
```

```bash
python manage.py test
```

## Before you call it production

- `DEBUG = False`, and `SECRET_KEY` / DB credentials from environment variables.
- `ALLOWED_HOSTS` set explicitly.
- `python manage.py check --deploy` — Django's own security checklist. Fix every warning.
- Serve with **gunicorn** behind a reverse proxy; static files via `collectstatic` + WhiteNoise or a CDN.
- Postgres, not SQLite, once more than one process writes.

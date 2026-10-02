---
title: "Building a REST API with Django REST Framework in 10 Steps"
excerpt: "In this article I would like to present how to build a REST API with Django REST Framework step by step — models, serializers, permissions, viewsets, routing, pagination, search and tests — ending with an authenticated API you can explore in the browser."
header:
  image: /images/posts/django-rest-api/project-list.png
---

<p align="center">
<img src="/images/posts/django-rest-api/project-list.png" alt="Django REST Framework browsable API" style="margin-inline:auto;"/>
</p>

<h3><strong>Short introduction</strong></h3>
Django is the backend framework behind several of my projects, including Mon9et, a Quran recitation checker my team built. When a frontend like Vue or a mobile app needs data, Django becomes an API server, and <strong>Django REST Framework (DRF)</strong> makes that surprisingly easy. In this article I would like to present how to build a complete REST API in 10 steps: a "projects" API with authentication, owner-only editing, pagination, search and tests. The screenshot above is the final result — DRF's browsable API, filled with a few of my own projects.

&nbsp;
<h3><strong>How a request flows through DRF</strong></h3>
Before we start, here is the path every request takes. We will build each of these boxes:

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

&nbsp;
<h3><strong>Step 1 — Create a virtual environment</strong></h3>

```bash
python -m venv venv && source venv/bin/activate
pip install django djangorestframework django-filter
pip freeze > requirements.txt
```

&nbsp;
<h3><strong>Step 2 — Create the project and the app</strong></h3>

```bash
django-admin startproject core .
python manage.py startapp projects
```

Then add the apps to `core/settings.py`:

```python
INSTALLED_APPS += ["rest_framework", "django_filters", "projects"]
```

&nbsp;
<h3><strong>Step 3 — The model</strong></h3>

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

&nbsp;
<h3><strong>Step 4 — Create the database tables</strong></h3>

```bash
python manage.py makemigrations
python manage.py migrate
python manage.py createsuperuser
```

&nbsp;
<h3><strong>Step 5 — The serializer</strong></h3>
The serializer converts model objects to JSON and back, and it is also where validation lives:

```python
# projects/serializers.py
from rest_framework import serializers
from .models import Project

class ProjectSerializer(serializers.ModelSerializer):
    owner = serializers.ReadOnlyField(source="owner.username")   # never trust the client for this

    class Meta:
        model  = Project
        fields = ["id", "owner", "name", "description", "tech", "is_public", "created_at"]

    def validate_name(self, value):
        if len(value.strip()) < 3:
            raise serializers.ValidationError("Name must be at least 3 characters.")
        return value.strip()
```

&nbsp;
<h3><strong>Step 6 — A permission class</strong></h3>
Everyone can read projects, but only the owner can change or delete one:

```python
# projects/permissions.py
from rest_framework import permissions

class IsOwnerOrReadOnly(permissions.BasePermission):
    def has_object_permission(self, request, view, obj):
        if request.method in permissions.SAFE_METHODS:      # GET, HEAD, OPTIONS
            return True
        return obj.owner == request.user
```

&nbsp;
<h3><strong>Step 7 — The ViewSet</strong></h3>
This is where DRF really saves time — the full create, read, update and delete logic in about 10 lines:

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
        return Project.objects.select_related("owner")      # avoids an extra query per project

    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)
```

&nbsp;
<h3><strong>Step 8 — Routes</strong></h3>

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

Now run `python manage.py runserver 8765` and open `http://127.0.0.1:8765/api/` in the browser. You should see the API root, with a link to our new endpoint:

<img src="/images/posts/django-rest-api/api-root.png" alt="DRF API root" style="margin-inline:auto;" />

That one `register` call created all of these endpoints:

| Method | URL | Action |
|---|---|---|
| GET | `/api/projects/` | List (paginated, filterable) |
| POST | `/api/projects/` | Create |
| GET | `/api/projects/{id}/` | Retrieve |
| PUT / PATCH | `/api/projects/{id}/` | Update |
| DELETE | `/api/projects/{id}/` | Delete |

&nbsp;
<h3><strong>Step 9 — Pagination, search, authentication and throttling</strong></h3>
Lets configure the defaults for the whole API in `core/settings.py`:

```python
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

Now search and ordering work with query parameters. For example `/api/projects/?search=django&ordering=-created_at` finds only the Django project:

<img src="/images/posts/django-rest-api/search-and-ordering.png" alt="Search and ordering in the browsable API" style="margin-inline:auto;" />

Once you log in (top right corner), a form appears at the bottom of the page. If I try to create a project with a name that is too short, the validation from step 5 returns a `400 Bad Request` with a clear message:

<img src="/images/posts/django-rest-api/validation-error.png" alt="Validation error in the browsable API" style="margin-inline:auto;" />

&nbsp;
<h3><strong>Step 10 — Test it</strong></h3>
The two most important behaviours are that the owner comes from the logged-in user (not from the request body), and that nobody can delete someone else's project:

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

```
$ python manage.py test
Creating test database for alias 'default'...
..
----------------------------------------------------------------------
Ran 2 tests in 2.660s

OK
```

> **_NOTE:_**  Before going to production: set `DEBUG = False`, read `SECRET_KEY` and database credentials from environment variables, set `ALLOWED_HOSTS`, run `python manage.py check --deploy` and fix every warning, serve the app with gunicorn behind a reverse proxy, and use PostgreSQL instead of SQLite. If you host on Azure, my [App Service article](/Azure-App-Service-Hosting-Guide/) shows how to deploy it.

&nbsp;
<h3><strong>Summary</strong></h3>
With Django REST Framework, a model, a serializer, a permission class and a ViewSet give you a complete REST API with validation and owner-based permissions, and a few settings add pagination, search, authentication and throttling. The browsable API is a great bonus: you can test every endpoint in the browser without any extra tools. You can read more in the official <a href="https://www.django-rest-framework.org/" target="_blank" rel="noopener">Django REST Framework documentation</a>.

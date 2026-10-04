---
title: "Docker From Zero: Host a Website and Seven Other Fun Things in Containers"
excerpt: "Docker is the tool I reach for on every side project. Here's the simple mental model, your first website running in 30 seconds, and eight genuinely fun things to build — from your own little cloud to a throwaway malware sandbox."
header:
  image: /images/posts/docker-start/hero.svg
tags: [Software, Web, Docker, containers, self-hosting, homelab]
---
![Docker from zero: host a website and other fun things in containers](/images/posts/docker-start/hero.svg)

Most of this blog is security, but I've been a builder far longer than I've been a defender — and on every side project, the tool I reach for first is **Docker**. Not because containers are trendy, but because Docker quietly killed the four most annoying words in software: *"works on my machine."*

This is the gentle, fun version of Docker. No Kubernetes, no microservices architecture diagrams. Just the mental model, a website running in about 30 seconds, and a pile of genuinely entertaining things you can spin up on a rainy afternoon.

## The whole idea, in one picture

Forget the jargon for a second. Docker lets you put an application **and everything it needs to run** — the right language version, libraries, config, all of it — into a single sealed box. That box runs identically on your laptop, your friend's laptop, or a $5 server, because the box *is* the environment.

Three words are all you need:

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 170" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="The Docker mental model: a Dockerfile is the recipe; you build it into an image, which is a frozen snapshot; you run the image to get a container, the live running app. Images are shared through a registry like Docker Hub.">
  <defs><marker id="d-a" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--accent)"/></marker></defs>
  <g style="font-size:12px;">
    <rect x="6" y="46" width="150" height="78" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="81" y="72" text-anchor="middle" font-size="22">📝</text>
    <text x="81" y="96" text-anchor="middle" font-weight="700" fill="var(--text)">Dockerfile</text>
    <text x="81" y="113" text-anchor="middle" fill="var(--text-muted)">the recipe</text>
    <rect x="200" y="46" width="150" height="78" rx="10" fill="var(--bg-elevated-2)" stroke="var(--accent)"/>
    <text x="275" y="72" text-anchor="middle" font-size="22">📦</text>
    <text x="275" y="96" text-anchor="middle" font-weight="700" fill="var(--accent)">Image</text>
    <text x="275" y="113" text-anchor="middle" fill="var(--text-muted)">frozen snapshot</text>
    <rect x="394" y="46" width="150" height="78" rx="10" fill="var(--accent)" fill-opacity="0.10" stroke="var(--accent-strong)"/>
    <text x="469" y="72" text-anchor="middle" font-size="22">🚀</text>
    <text x="469" y="96" text-anchor="middle" font-weight="700" fill="var(--text)">Container</text>
    <text x="469" y="113" text-anchor="middle" fill="var(--text-muted)">the live app</text>
    <rect x="556" y="46" width="80" height="78" rx="10" fill="none" stroke="var(--text-muted)" stroke-dasharray="5 4"/>
    <text x="596" y="80" text-anchor="middle" font-size="20">🏪</text>
    <text x="596" y="104" text-anchor="middle" fill="var(--text-muted)">registry</text>
    <line x1="156" y1="85" x2="198" y2="85" stroke="var(--accent)" stroke-width="2" marker-end="url(#d-a)"/>
    <text x="177" y="38" text-anchor="middle" fill="var(--text-muted)" font-size="10">build</text>
    <line x1="350" y1="85" x2="392" y2="85" stroke="var(--accent)" stroke-width="2" marker-end="url(#d-a)"/>
    <text x="372" y="38" text-anchor="middle" fill="var(--text-muted)" font-size="10">run</text>
    <line x1="554" y1="85" x2="546" y2="85" stroke="var(--text-muted)" stroke-width="1.5" marker-end="url(#d-a)"/>
    <text x="320" y="152" text-anchor="middle" fill="var(--text-muted)">A <tspan font-weight="700" fill="var(--text)">Dockerfile</tspan> bakes into an <tspan font-weight="700" fill="var(--text)">image</tspan>; running an image gives you a <tspan font-weight="700" fill="var(--text)">container</tspan>. Pull ready-made images from a registry.</text>
  </g>
</svg>
</div>

If cooking helps: the **Dockerfile** is the recipe, the **image** is the frozen ready-meal, and the **container** is the dish actually cooking on your stove. The **registry** (Docker Hub) is the shop where you grab ready-made meals instead of cooking from scratch.

## Install it and prove it works

Grab **Docker Desktop** (macOS/Windows) or Docker Engine (Linux) from [docker.com](https://www.docker.com/), then confirm it's alive:

```bash
docker run hello-world
```

That one command pulls a tiny image from the registry, runs it in a container, prints a friendly message, and exits. You just ran your first container. That's the whole loop.

## Project 1 — host a website in 30 seconds

Here's the moment Docker clicks for most people. Want a real web server? Don't install anything:

```bash
docker run -d -p 8080:80 nginx
```

Open `http://localhost:8080` and there's a running Nginx web server. `-d` runs it in the background, and `-p 8080:80` wires your laptop's port 8080 to port 80 inside the container.

Now make it *your* site — mount a folder of your own HTML into it:

```bash
# put an index.html in the current folder, then:
docker run -d -p 8080:80 -v "$PWD":/usr/share/nginx/html nginx
```

Refresh, and you're looking at your own page. When you want it reproducible — the thing you can hand to anyone or deploy to a server — write a tiny **Dockerfile**:

```dockerfile
# Dockerfile
FROM nginx:alpine
COPY . /usr/share/nginx/html
```

```bash
docker build -t my-site .        # bake the image
docker run -d -p 8080:80 my-site # run it anywhere, forever
```

That image now contains your whole site *and* its web server. It runs the same on your machine and on a $5 VPS. That's the magic in one example.

## Two containers that talk: Compose

Real apps are usually more than one piece — a site *and* a database. **Docker Compose** describes the whole set in one file so `docker compose up` starts everything together:

```yaml
# docker-compose.yml
services:
  web:
    build: .
    ports: ["8080:80"]
  db:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: devsecret
    volumes: ["dbdata:/var/lib/postgresql/data"]
volumes:
  dbdata:
```

```bash
docker compose up -d     # both containers, one command
docker compose down      # stop and clean up
```

One file, your whole stack. Commit it next to your code and anyone can run your project in seconds.

## Eight genuinely fun things to build

This is where it gets addictive. Once you realise your laptop can run *anything* in a throwaway box, the ideas don't stop.

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 300" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Eight fun Docker project ideas: host your own website or portfolio; spin up a throwaway database; self-host your own apps as a personal cloud; a disposable sandbox for sketchy files; try any Linux tool without installing; a clean dev environment per project; a game server or bot for friends; and run an AI model locally.">
  <g style="font-size:11.5px;">
    <rect x="4" y="8" width="206" height="88" rx="10" fill="var(--bg-elevated-2)" stroke="var(--accent)"/>
    <text x="20" y="32" font-size="18">🌐</text><text x="48" y="34" font-weight="700" fill="var(--text)">1 · Your website</text>
    <text x="20" y="58" fill="var(--text-muted)">portfolio or blog on</text><text x="20" y="74" fill="var(--text-muted)">Nginx, deploy anywhere</text>
    <rect x="217" y="8" width="206" height="88" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="233" y="32" font-size="18">🗄️</text><text x="261" y="34" font-weight="700" fill="var(--text)">2 · Throwaway DB</text>
    <text x="233" y="58" fill="var(--text-muted)">Postgres/Redis for a</text><text x="233" y="74" fill="var(--text-muted)">test, delete after</text>
    <rect x="430" y="8" width="206" height="88" rx="10" fill="var(--accent)" fill-opacity="0.10" stroke="var(--accent-strong)"/>
    <text x="446" y="32" font-size="18">☁️</text><text x="474" y="34" font-weight="700" fill="var(--text)">3 · Your own cloud</text>
    <text x="446" y="58" fill="var(--text-muted)">self-host apps: notes,</text><text x="446" y="74" fill="var(--text-muted)">passwords, dashboards</text>
    <rect x="4" y="106" width="206" height="88" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="20" y="130" font-size="18">🧪</text><text x="48" y="132" font-weight="700" fill="var(--text)">4 · Sandbox</text>
    <text x="20" y="156" fill="var(--text-muted)">open sketchy files in a</text><text x="20" y="172" fill="var(--text-muted)">throwaway box</text>
    <rect x="217" y="106" width="206" height="88" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="233" y="130" font-size="18">🐧</text><text x="261" y="132" font-weight="700" fill="var(--text)">5 · Try any tool</text>
    <text x="233" y="156" fill="var(--text-muted)">a Linux toolbox without</text><text x="233" y="172" fill="var(--text-muted)">installing a thing</text>
    <rect x="430" y="106" width="206" height="88" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="446" y="130" font-size="18">🧰</text><text x="474" y="132" font-weight="700" fill="var(--text)">6 · Dev per project</text>
    <text x="446" y="156" fill="var(--text-muted)">no more version clashes</text><text x="446" y="172" fill="var(--text-muted)">between projects</text>
    <rect x="110" y="204" width="206" height="88" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="126" y="228" font-size="18">🎮</text><text x="154" y="230" font-weight="700" fill="var(--text)">7 · Game / bot</text>
    <text x="126" y="254" fill="var(--text-muted)">Minecraft server or a</text><text x="126" y="270" fill="var(--text-muted)">Discord bot for friends</text>
    <rect x="323" y="204" width="206" height="88" rx="10" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="339" y="228" font-size="18">🤖</text><text x="367" y="230" font-weight="700" fill="var(--text)">8 · Local AI</text>
    <text x="339" y="254" fill="var(--text-muted)">run an LLM in a box,</text><text x="339" y="270" fill="var(--text-muted)">no cloud, no bills</text>
  </g>
</svg>
</div>

1. **Host your own website or portfolio.** Exactly what we just did — then push the image to a cheap server and it's live.
2. **A throwaway database.** Need Postgres for ten minutes to test something? `docker run -d -e POSTGRES_PASSWORD=dev -p 5432:5432 postgres`. When you're done, `docker rm -f` it — your laptop stays clean, no leftover install.
3. **Your own little cloud (self-hosting).** This is the gateway drug. Run privacy-friendly versions of apps you'd normally rent: a password manager ([Vaultwarden](https://github.com/dani-garcia/vaultwarden)), a notes app, a read-later service, a network-wide ad blocker ([Pi-hole](https://pi-hole.net/)), a personal dashboard. One `docker compose up` each, and you've built a homelab.
4. **A disposable sandbox.** Open a suspicious document or poke at a sketchy link inside a container you throw away afterwards — the mess stays in the box, not on your machine. (This is the on-ramp to the serious version in my [malware-analysis lab](/FLARE-VM-Malware-Analysis-Lab/) posts.)
5. **Try any Linux tool without installing it.** Want to test a command-line tool once? `docker run --rm -it ubuntu bash` drops you into a clean Linux shell that vanishes on exit. `--rm` means "delete the container when it stops."
6. **A clean dev environment per project.** Project A needs Node 18, Project B needs Node 22? Give each its own container and never fight a version conflict again.
7. **A game server or a bot.** A Minecraft server for friends, or a Discord bot that just runs — containers make "leave it running" trivial, and tearing it down is one command.
8. **Run an AI model locally.** Pair this with my [local agentic-AI guide](/Agentic-AI-Run-It-Locally/): `docker run -d -p 11434:11434 ollama/ollama` gives you a private LLM server in a box — no API key, nothing leaves your machine.

## Keep it tidy (so it doesn't eat your disk)

Two habits save you from Docker's one real annoyance — silently filling your disk:

```bash
docker ps              # what's running right now
docker ps -a           # everything, including stopped containers
docker system prune    # reclaim space: remove stopped containers, unused images
```

And one concept worth knowing early: **volumes**. A container's own filesystem is disposable — delete the container and its data is gone. If you want data to survive (a database, your notes app), store it in a **volume** (the `-v dbdata:/path` bits above). Disposable by default, persistent on purpose.

> **A little caution:** containers are isolated, not magic. Only run images from sources you trust (official images on Docker Hub are a safe start), don't paste `docker run` commands you don't understand that mount your whole disk, and remember that `-p` exposes a port on your network. For the *serious* flip side — what containers mean when you're the one investigating a breach — see my [DFIR considerations for Docker](/DFIR-Considerations-for-Docker-Containers/).

## Where this leaves you

Docker's whole promise is that the gap between "it runs on my laptop" and "it runs on a server for the world" collapses into one image you can hand to anyone. Start with the website — `docker run -d -p 8080:80 nginx` — then pick one idea from the list and give yourself a weekend. The best way to learn Docker isn't a course; it's self-hosting something you actually want to use.

Worth reading next: the [Docker docs' getting-started guide](https://docs.docker.com/get-started/), [Awesome-Selfhosted](https://github.com/awesome-selfhosted/awesome-selfhosted) for a rabbit-hole of apps to run, and — when you're ready for the security angle — my [DFIR considerations for Docker containers](/DFIR-Considerations-for-Docker-Containers/).

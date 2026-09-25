---
title: "DFIR Considerations for Docker Containers"
excerpt: "Containers break a lot of assumptions incident responders take for granted — persistent disk, long-lived processes, a filesystem that looks the same tomorrow as it did today. Here's what actually changes when the thing you're investigating is a Docker container, and how to acquire evidence before it disappears."
---

Most DFIR training assumes a host that sits still: a disk you can image, a filesystem that isn't going anywhere, processes that have been running long enough to leave a trail. Containers break most of that. A compromised container can be gone — stopped, removed, rescheduled onto a different node — minutes after the thing that triggered your alert happened. If you don't know what's different going in, you'll lose evidence you didn't even know was time-limited.

This isn't a "containers vs VMs" theory post. It's the practical checklist I actually reach for when a container is in scope.

## The core problem: ephemeral by design

Containers are meant to be disposable. That's the whole point of the model — and it's exactly what works against you during an investigation:

- **The writable layer disappears with the container.** Anything the process wrote at runtime lives in a thin, container-specific overlay layer on top of the read-only image. `docker rm` (or a scheduler rescheduling the pod) takes that layer with it.
- **There's often no persistent host artifact.** Unlike a compromised VM, there's frequently nothing left on the node once the container's gone — no separate disk, no easy "mount the image and look around."
- **Short-lived by default.** Build pipelines, serverless-style workloads, and auto-scaling groups routinely spin containers up and down in minutes. If your detection has any lag at all, the container that triggered it may not exist by the time you respond.

The practical upshot: for containers, acquisition speed matters more than it does almost anywhere else in DFIR. Decide your capture plan *before* you have an incident, not while you're staring at a container that might vanish in the next scheduler cycle.

## Live acquisition: what to pull, and in what order

If the container is still running, prioritize the things that die first.

**1. Process and network state (most volatile)**

{% raw %}
```bash
docker top <container_id>
docker exec <container_id> ps auxf
docker inspect <container_id> --format '{{json .State}}'
```
{% endraw %}

`docker inspect` also gives you the container's network namespace, mounted volumes, environment variables, and the exact image digest it was started from — all of which you want in your case notes regardless of what else you collect.

**2. The writable layer and filesystem diff**

`docker diff` shows you every file added, changed, or deleted relative to the base image — often the fastest way to spot a dropped webshell or modified binary without diffing the whole filesystem by hand:

```bash
docker diff <container_id>
```

For a full copy of the container's filesystem as it currently stands:

```bash
docker export <container_id> -o container_fs.tar
```

Note that `export` flattens the container to a single filesystem snapshot — you lose the layer history in the process. If layer-by-layer provenance matters (e.g., you need to prove *which* layer introduced a file), work from `docker save` on the image instead, or go straight to the host-level storage driver.

**3. Logs**

```bash
docker logs <container_id> --timestamps > container_logs.txt
```

Don't stop at `docker logs` — check where the logging driver is actually writing on the host (`json-file` under `/var/lib/docker/containers/<id>/`, or wherever your driver of choice sends it). If centralized logging (Fluentd, an ELK/EFK stack, CloudWatch) is in place, pull from there too; container-local logs can be truncated, rotated, or lost along with the container itself.

**4. Memory**

Containers share the host kernel, so there's no separate "container memory" to acquire the way you'd image a VM's RAM. What you *can* do is target the container's specific process(es) on the host:

{% raw %}
```bash
# find the host PID for a process inside the container
docker inspect <container_id> --format '{{.State.Pid}}'
```
{% endraw %}

From there, standard Linux memory forensics against that PID (or the whole host, if you have the budget for it) applies.

## Acquisition after the container is already gone

This is the case that actually hurts. A few things still might save the investigation:

- **The image is not the container.** If the image is still in the local registry or cache, `docker save` gets you the base filesystem and layer history — useful for understanding what the container looked like *before* runtime changes, but it won't show you anything the attacker did at runtime.
- **Volumes often outlive the container.** Any named volume or bind mount the container used typically persists after `docker rm`. Check `docker volume ls` and don't assume everything walked out the door with the container.
- **The host itself is still an artifact.** Container runtime logs (`dockerd`/`containerd` logs), the overlay2 storage driver's on-disk layers under `/var/lib/docker/overlay2/`, and host-level EDR/auditd telemetry frequently retain evidence of what happened even after the container object is deleted.
- **Orchestrator-level history.** In Kubernetes, check for previous pod events (`kubectl get events`), and if a pod was OOMKilled or evicted rather than deliberately removed, `kubectl logs --previous` can recover the last container instance's logs even after a restart.

## What to fix before the next incident

The single highest-leverage change, if you can make it stick: **ship logs and runtime telemetry off-host, continuously, before anything happens.** Everything above is a "try to recover evidence that might already be gone" exercise. A runtime security tool watching syscalls (Falco is the common open-source choice) or simply making sure container logs land somewhere durable turns most of this from forensic recovery into a straightforward log query.

Beyond that: know your acquisition commands cold, and decide in advance whether a suspicious container gets paused (`docker pause`, which freezes it without killing it — often the best first move if you're not sure yet) versus killed. Once it's gone, you're working with whatever you had the foresight to ship elsewhere.

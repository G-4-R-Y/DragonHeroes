# infra/ — deployment

Target (docs/tech/22 §hosting): Agones on Kubernetes in São Paulo
(GKE southamerica-east1 or EKS sa-east-1 — open decision, docs/tech/20) for
persistent world zones; Edgegap for burst capacity (tournaments, Gloomfall) —
both behind a thin GameServerProvider abstraction (the Hathora shutdown lesson:
never couple to one host vendor).

- `docker/` — container builds (`dh-server` first; see `docker/dh-server.Dockerfile`).
- Terraform/K8s manifests land with M2.

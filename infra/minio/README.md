# MinIO (`infra/minio`)

MinIO provides S3-compatible object storage for media and binary assets.

## Tech Stack

`MinIO` `S3-Compatible API` `Docker` `Docker Compose`

## Stack Audit

### Current stack tags

`MinIO` `S3-Compatible API` `Docker` `Docker Compose`

### What this means in this project

- `MinIO`: object storage backend for files, media, and binary artifacts.
- `S3-Compatible API`: integration compatible with standard S3 clients/SDKs.
- `Docker Compose`: local deployment and consistent service wiring.

### Professional additions recommended

- Bucket policy model (private/public) documented per bucket
- Access key rotation and secret management policy
- Lifecycle rules for retention and cost/storage control
- Server-side encryption and TLS plan for non-local setups
- Object versioning strategy for critical assets
- Monitoring and alerting for storage usage and failed operations

## Docker Compose service

- Service name: `minio`
- Image: `minio/minio:RELEASE.2024-10-02T17-50-41Z`
- Container name: `forgetmenot-minio`
- Command: `server /data --console-address ":9001"`
- Port mappings:
  - `9000:9000` (S3 API)
  - `9001:9001` (web console)
- Volume: `minio_data:/data`

Default credentials:

- Access key (root user): `minioadmin`
- Secret key (root password): `minioadmin`

## Operational notes

- Current credentials are development defaults only.
- Object data persists in `minio_data`.
- Console access is useful for bucket inspection and policy checks.

## Start only MinIO

From repo root:

```bash
docker compose up -d minio
```

## Access points

- API: `http://localhost:9000`
- Console: `http://localhost:9001`

## Verify MinIO

```bash
docker compose ps minio
```

Then login at `http://localhost:9001` with the default credentials above.

Quick API reachability check:

```bash
curl http://localhost:9000/minio/health/live
```

## Connection from backend

Configured via environment in `docker-compose.yml`:

- `MINIO_HOST=minio`
- `MINIO_PORT=9000`

## Troubleshooting

- **Cannot login to console:** verify credentials in compose env vars.
- **Uploads fail from backend:** confirm backend endpoint/port and bucket permissions.
- **Data not retained:** validate `minio_data` volume mount.
- **Access denied errors:** review bucket policies and object ACL behavior.

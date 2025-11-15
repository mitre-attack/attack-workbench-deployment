# Troubleshooting

Here are a few commands you can use to troubleshoot the docker compose setup.

```bash
# View running containers
docker compose ps

# Show logs for all running containers
docker compose logs

# Follow logs
docker compose logs -f

# Show logs for a specific container
docker compose logs frontend
docker compose logs rest-api
docker compose logs database
docker compose logs taxii
```

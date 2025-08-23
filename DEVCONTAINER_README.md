# OCB 18.0 Development Container

This project provides a complete devcontainer setup for developing with Odoo Community Backports (OCB) 18.0.

## Quick Start

1. **Open in VS Code**: Make sure you have the "Dev Containers" extension installed
2. **Reopen in Container**:
   - Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac)
   - Type "Dev Containers: Reopen in Container"
   - Select the option and wait for the container to build

3. **Start PostgreSQL and Odoo**:

   ```bash
   # The database will start automatically with docker-compose
   # To start Odoo, run in the terminal:
   /opt/odoo/start-odoo.sh
   ```

4. **Access Odoo**: Open <http://localhost:8069> in your browser

## What's Included

- **OCB 18.0**: Latest Odoo Community Backports
- **PostgreSQL 15**: Database server
- **Python Virtual Environment**: Pre-configured with all dependencies

## Development Workflow

### Starting Odoo

```bash
# Basic start
/opt/odoo/start-odoo.sh

# With custom database
source /opt/odoo/venv/bin/activate
/opt/odoo/src/odoo/odoo-bin -c /opt/odoo/odoo.conf -d mydb

# Initialize a new database
/opt/odoo/src/odoo/odoo-bin -c /opt/odoo/odoo.conf -d mydb -i base --stop-after-init
```

### Custom Modules

- Place your custom modules in the `custom-addons/` directory
- They will be automatically available in Odoo's addons path

## Database Access

- **Host**: `localhost` (from host machine) or `db` (from container)
- **Port**: `5432`
- **User**: `odoo`
- **Password**: `odoo`
- **Default DB**: `postgres`

## Environment Variables

You can customize the environment by modifying `.devcontainer/docker-compose.yml`:

- `ODOO_ADMIN_PASSWD`: Admin password (default: `admin`)
- `LOG_LEVEL`: Logging level (default: `info`)
- `WORKERS`: Number of worker processes (default: `0` for development)

## Container Structure

- `/opt/odoo/src/odoo`: OCB source code
- `/opt/odoo/custom-addons`: Your custom modules (mounted from `./custom-addons`)
- `/opt/odoo/venv`: Python virtual environment
- `/opt/odoo/data`: Odoo data directory
- `/var/log/odoo`: Log files
- `/workspace`: Project root (mounted from current directory)

## Troubleshooting

### Container won't start
Make sure the `ocb-dev:latest` Docker image exists:
```bash
docker images | grep ocb-dev
```

If not, build it first:
```bash
docker build --target development -t ocb-dev:latest .
```

### Database connection issues
Check if PostgreSQL is running:
```bash
docker-compose -f .devcontainer/docker-compose.yml ps
```

### Port conflicts
If ports 8069 or 5432 are already in use, modify the ports in `.devcontainer/docker-compose.yml`.

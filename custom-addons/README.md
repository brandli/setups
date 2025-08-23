# Custom Addons Directory

This directory is for your custom Odoo modules.

## Usage

1. Place your custom modules in this directory
2. Each module should have its own subdirectory with a `__manifest__.py` file
3. The modules will be automatically available in Odoo

## Example Structure

```
custom-addons/
├── my_custom_module/
│   ├── __init__.py
│   ├── __manifest__.py
│   ├── models/
│   ├── views/
│   └── ...
└── another_module/
    ├── __init__.py
    ├── __manifest__.py
    └── ...
```

## Starting Odoo

In the VS Code terminal (inside the devcontainer), run:

```bash
# Generate config and start Odoo
/opt/odoo/start-odoo.sh

# Or run with specific parameters
source /opt/odoo/venv/bin/activate
/opt/odoo/src/odoo/odoo-bin -c /opt/odoo/odoo.conf -d mydb -i base --stop-after-init

# Or start normally
/opt/odoo/src/odoo/odoo-bin -c /opt/odoo/odoo.conf
```

## Database Access

- **Host**: `db` (from within container) or `localhost` (from host)
- **Port**: `5432`
- **Database**: `postgres`
- **User**: `odoo`
- **Password**: `odoo`

# Multi-stage Dockerfile for OCB 18.0 on Ubuntu
# Can be used for both development and production

# Development stage - includes all dev tools
FROM ubuntu:22.04 AS dev-base

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    LANG=C.UTF-8 \
    TZ=UTC

# Update and install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Python and build essentials
    python3 \
    python3-pip \
    python3-dev \
    python3-venv \
    build-essential \
    # Development tools
    git \
    curl \
    wget \
    vim \
    nano \
    htop \
    tree \
    less \
    # OCB system dependencies
    libxml2-dev \
    libxslt1-dev \
    zlib1g-dev \
    libsasl2-dev \
    libldap2-dev \
    libjpeg-dev \
    libpq-dev \
    libffi-dev \
    libssl-dev \
    libpng-dev \
    libjpeg-turbo8-dev \
    # JavaScript dependencies
    nodejs \
    npm \
    node-less \
    # PostgreSQL client
    postgresql-client \
    # Additional utilities
    ca-certificates \
    gettext-base \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install rtlcss for right-to-left languages
RUN npm install -g rtlcss

# Install wkhtmltopdf (specific version for headers/footers support)
RUN wget -q https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_amd64.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends ./wkhtmltox_0.12.6.1-3.jammy_amd64.deb \
    && rm wkhtmltox_0.12.6.1-3.jammy_amd64.deb \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create odoo user and directories
RUN groupadd -r odoo && useradd -r -g odoo -d /opt/odoo -s /bin/bash odoo \
    && mkdir -p /opt/odoo/src \
    && mkdir -p /opt/odoo/data \
    && mkdir -p /opt/odoo/logs \
    && mkdir -p /opt/odoo/custom-addons \
    && mkdir -p /var/log/odoo \
    && chown -R odoo:odoo /opt/odoo /var/log/odoo \
    && chmod 755 /var/log/odoo

# Switch to odoo user
USER odoo
WORKDIR /opt/odoo

# Create Python virtual environment
RUN python3 -m venv venv

# Activate venv and upgrade pip
RUN /opt/odoo/venv/bin/pip install --upgrade pip setuptools wheel

# Clone OCB 18.0
RUN git clone --depth 1 --branch 18.0 https://github.com/OCA/OCB.git /opt/odoo/src/odoo

# Clean up enterprise references and upgrade prompts
RUN find /opt/odoo/src/odoo -name "*.py" -exec sed -i '/enterprise.*upgrade\|upgrade.*enterprise/d' {} \; && \
    find /opt/odoo/src/odoo -name "*.js" -exec sed -i '/enterprise.*upgrade\|odoo-enterprise\/upgrade/d' {} \; && \
    find /opt/odoo/src/odoo -name "*.xml" -exec sed -i '/enterprise_upgrade\|upgrade.*enterprise/d' {} \; && \
    rm -rf /opt/odoo/src/odoo/addons/web/static/img/enterprise_upgrade.jpg 2>/dev/null || true

# Install Python dependencies with gevent compatibility fix
# First install everything except gevent, then install a compatible gevent version
RUN sed '/^gevent==/d' /opt/odoo/src/odoo/requirements.txt > /tmp/requirements-no-gevent.txt && \
    /opt/odoo/venv/bin/pip install -r /tmp/requirements-no-gevent.txt && \
    /opt/odoo/venv/bin/pip install 'gevent>=22.8.0'

# Create a simple entrypoint script that handles environment variables but allows args
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# Set default values for environment variables\n\
export DB_HOST=${DB_HOST:-db}\n\
export DB_PORT=${DB_PORT:-5432}\n\
export DB_USER=${DB_USER:-odoo}\n\
export DB_PASSWORD=${DB_PASSWORD:-}\n\
export LOG_LEVEL=${LOG_LEVEL:-info}\n\
export WORKERS=${WORKERS:-0}\n\
export MAX_CRON_THREADS=${MAX_CRON_THREADS:-1}\n\
\n\
# Activate virtual environment\n\
source /opt/odoo/venv/bin/activate\n\
\n\
# If no arguments provided, use default Odoo startup\n\
if [ $# -eq 0 ]; then\n\
    set -- /opt/odoo/src/odoo/odoo-bin \\\n\
        --db_host="$DB_HOST" \\\n\
        --db_port="$DB_PORT" \\\n\
        --db_user="$DB_USER" \\\n\
        --db_password="$DB_PASSWORD" \\\n\
        --addons-path="/opt/odoo/src/odoo/addons,/opt/odoo/custom-addons" \\\n\
        --data-dir="/opt/odoo/data" \\\n\
        --log-level="$LOG_LEVEL" \\\n\
        --workers="$WORKERS" \\\n\
        --max-cron-threads="$MAX_CRON_THREADS" \\\n\
        --database="${ODOO_DB:-odoo}"\n\
fi\n\
\n\
# Execute the command\n\
exec "$@"' > /opt/odoo/docker-entrypoint.sh \
    && chmod +x /opt/odoo/docker-entrypoint.sh

# Expose port
EXPOSE 8069

# Set the entrypoint and default command
ENTRYPOINT ["/opt/odoo/docker-entrypoint.sh"]
CMD ["/opt/odoo/src/odoo/odoo-bin", "--addons-path=/opt/odoo/src/odoo/addons,/opt/odoo/custom-addons", "--data-dir=/opt/odoo/data"]

# Development stage - final dev image
FROM dev-base AS development

# Set environment for development
ENV ODOO_ENV=development

# Install additional development tools
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    iputils-ping \
    telnet \
    strace \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

USER odoo

# Install development Python packages
RUN /opt/odoo/venv/bin/pip install \
    debugpy \
    ipdb \
    pytest \
    coverage

# Development stage inherits the entrypoint from dev-base
# No need to override CMD as it uses the same odoo-bin

# Production stage - stripped down version
FROM dev-base AS production

USER root

# Remove only heavy development packages, keep git and nano
RUN apt-get update && apt-get remove -y --purge \
    vim \
    htop \
    tree \
    build-essential \
    python3-dev \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

USER odoo

# Set environment for production
ENV ODOO_ENV=production

# Override default environment variables for production
ENV WORKERS=4 \
    LOG_LEVEL=warn \
    MAX_CRON_THREADS=1

# Production uses the same entrypoint but with different defaults

# Default to development stage
FROM development
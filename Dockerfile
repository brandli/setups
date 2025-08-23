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
    && chown -R odoo:odoo /opt/odoo /var/log/odoo

# Switch to odoo user
USER odoo
WORKDIR /opt/odoo

# Create Python virtual environment
RUN python3 -m venv venv

# Activate venv and upgrade pip
RUN /opt/odoo/venv/bin/pip install --upgrade pip setuptools wheel

# Clone OCB 18.0
RUN git clone --depth 1 --branch 18.0 https://github.com/OCA/OCB.git /opt/odoo/src/odoo

# Install Python dependencies with gevent compatibility fix
# First install everything except gevent, then install a compatible gevent version
RUN sed '/^gevent==/d' /opt/odoo/src/odoo/requirements.txt > /tmp/requirements-no-gevent.txt && \
    /opt/odoo/venv/bin/pip install -r /tmp/requirements-no-gevent.txt && \
    /opt/odoo/venv/bin/pip install 'gevent>=22.8.0'

# Create minimal Odoo configuration template
RUN echo "[options]" > /opt/odoo/odoo.conf.template && \
    echo "# Database settings - override with environment variables" >> /opt/odoo/odoo.conf.template && \
    echo "db_host = \${DB_HOST:-db}" >> /opt/odoo/odoo.conf.template && \
    echo "db_port = \${DB_PORT:-5432}" >> /opt/odoo/odoo.conf.template && \
    echo "db_user = \${DB_USER:-odoo}" >> /opt/odoo/odoo.conf.template && \
    echo "db_password = \${DB_PASSWORD:-}" >> /opt/odoo/odoo.conf.template && \
    echo "" >> /opt/odoo/odoo.conf.template && \
    echo "# Odoo settings" >> /opt/odoo/odoo.conf.template && \
    echo "addons_path = /opt/odoo/src/odoo/addons,/opt/odoo/custom-addons" >> /opt/odoo/odoo.conf.template && \
    echo "data_dir = /opt/odoo/data" >> /opt/odoo/odoo.conf.template && \
    echo "logfile = /var/log/odoo/odoo.log" >> /opt/odoo/odoo.conf.template && \
    echo "log_level = \${LOG_LEVEL:-info}" >> /opt/odoo/odoo.conf.template && \
    echo "workers = \${WORKERS:-0}" >> /opt/odoo/odoo.conf.template && \
    echo "max_cron_threads = \${MAX_CRON_THREADS:-1}" >> /opt/odoo/odoo.conf.template && \
    echo "" >> /opt/odoo/odoo.conf.template && \
    echo "# Security - DO NOT set admin password in config file" >> /opt/odoo/odoo.conf.template && \
    echo "# Set ODOO_ADMIN_PASSWD environment variable instead" >> /opt/odoo/odoo.conf.template && \
    echo "# admin_passwd = " >> /opt/odoo/odoo.conf.template

# Expose port
EXPOSE 8069

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

# Create startup script for development
RUN echo '#!/bin/bash\n\
\n\
# Generate config from template with environment variable substitution\n\
envsubst < /opt/odoo/odoo.conf.template > /opt/odoo/odoo.conf\n\
\n\
# Set admin password from environment if provided\n\
if [ -n "$ODOO_ADMIN_PASSWD" ]; then\n\
    echo "admin_passwd = $ODOO_ADMIN_PASSWD" >> /opt/odoo/odoo.conf\n\
fi\n\
\n\
# Activate virtual environment and start Odoo\n\
source /opt/odoo/venv/bin/activate\n\
exec /opt/odoo/src/odoo/odoo-bin -c /opt/odoo/odoo.conf "$@"' > /opt/odoo/start-odoo.sh \
    && chmod +x /opt/odoo/start-odoo.sh

CMD ["/opt/odoo/start-odoo.sh"]

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

# Update configuration for production
RUN sed -i 's/WORKERS:-0/WORKERS:-4/' /opt/odoo/odoo.conf.template \
    && sed -i 's/LOG_LEVEL:-info/LOG_LEVEL:-warn/' /opt/odoo/odoo.conf.template

# Create startup script for production
RUN echo '#!/bin/bash\n\
\n\
# Generate config from template with environment variable substitution\n\
envsubst < /opt/odoo/odoo.conf.template > /opt/odoo/odoo.conf\n\
\n\
# Set admin password from environment if provided\n\
if [ -n "$ODOO_ADMIN_PASSWD" ]; then\n\
    echo "admin_passwd = $ODOO_ADMIN_PASSWD" >> /opt/odoo/odoo.conf\n\
fi\n\
\n\
# Activate virtual environment and start Odoo\n\
source /opt/odoo/venv/bin/activate\n\
exec /opt/odoo/src/odoo/odoo-bin -c /opt/odoo/odoo.conf "$@"' > /opt/odoo/start-odoo.sh \
    && chmod +x /opt/odoo/start-odoo.sh

CMD ["/opt/odoo/start-odoo.sh"]

# Default to development stage
FROM development
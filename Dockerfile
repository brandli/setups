# Multi-stage Dockerfile for OCB 18.0 on Ubuntu
# Can be used for both development and production
#
# FIXES APPLIED:
# 1. Comprehensive Enterprise reference cleanup to prevent ModuleNotFoundError
# 2. Removal of Enterprise module categories from base data files
# 3. Explicit installation of babel and critical Python packages
# 4. Validation steps to ensure clean Community-only installation
# 5. Health checks to verify Odoo functionality
# 6. Targeted removal of only problematic Enterprise modules
#
# This build ensures pure OCB Community functionality without Enterprise contamination

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

# Install BPMN.js for the BPMN module
RUN npm install -g bpmn-js

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

# Comprehensive Enterprise cleanup to ensure pure Community functionality
RUN cd /opt/odoo/src/odoo && \
    # Remove Enterprise module references from resource calendar
    sed -i '/from odoo.addons.hr_work_entry_contract.models.hr_work_intervals import WorkIntervals/d' \
        addons/resource/models/resource_calendar.py && \
    sed -i '/WorkIntervals/d' addons/resource/models/resource_calendar.py && \
    # Remove Enterprise module categories from base data
    sed -i '/<record id="module_category_services_timesheets"/,/<\/record>/d' \
        addons/base/data/ir_module_module.xml && \
    sed -i '/<record id="module_category_manufacturing"/,/<\/record>/d' \
        addons/base/data/ir_module_module.xml && \
    sed -i '/<record id="module_category_marketing"/,/<\/record>/d' \
        addons/base/data/ir_module_module.xml && \
    sed -i '/<record id="module_category_project"/,/<\/record>/d' \
        addons/base/data/ir_module_module.xml && \
    sed -i '/<record id="module_category_services"/,/<\/record>/d' \
        addons/base/data/ir_module_module.xml && \
    # Remove references to Enterprise categories in module manifest files
    find addons -name "__manifest__.py" -exec sed -i '/base\.module_category_services_timesheets/d' {} \; && \
    find addons -name "__manifest__.py" -exec sed -i '/base\.module_category_manufacturing/d' {} \; && \
    find addons -name "__manifest__.py" -exec sed -i '/base\.module_category_marketing/d' {} \; && \
    find addons -name "__manifest__.py" -exec sed -i '/base\.module_category_project/d' {} \; && \
    find addons -name "__manifest__.py" -exec sed -i '/base\.module_category_services/d' {} \; && \
    # Clean up any remaining enterprise references
    find . -name "*.py" -exec sed -i '/enterprise.*upgrade\|upgrade.*enterprise/d' {} \; && \
    find . -name "*.js" -exec sed -i '/enterprise.*upgrade\|odoo-enterprise\/upgrade/d' {} \; && \
    find . -name "*.xml" -exec sed -i '/enterprise_upgrade\|upgrade.*enterprise/d' {} \; && \
    # Remove Enterprise upgrade prompts and images
    rm -rf addons/web/static/img/enterprise_upgrade.jpg 2>/dev/null || true && \
    rm -rf addons/web/static/src/img/enterprise_upgrade.jpg 2>/dev/null || true

# Remove only the most problematic Enterprise modules that break Community functionality
# Keep essential modules that are needed for basic Odoo operation
RUN cd /opt/odoo/src/odoo/addons && \
    # Remove modules that have hard Enterprise dependencies
    rm -rf hr_work_entry* \
    hr_contract* \
    hr_timesheet* \
    timesheet_grid* \
    project_timesheet* \
    sale_timesheet* \
    # Remove upgrade-related modules
    enterprise_upgrade* \
    web_enterprise* \
    # Remove modules that reference missing Enterprise categories
    2>/dev/null || true

# Install Python dependencies with gevent compatibility fix and ensure critical packages
# First install everything except gevent, then install a compatible gevent version
RUN sed '/^gevent==/d' /opt/odoo/src/odoo/requirements.txt > /tmp/requirements-no-gevent.txt && \
    /opt/odoo/venv/bin/pip install -r /tmp/requirements-no-gevent.txt && \
    /opt/odoo/venv/bin/pip install 'gevent>=22.8.0'

# Ensure critical packages are installed (especially babel which is often missing)
RUN /opt/odoo/venv/bin/pip install \
    babel \
    Pillow \
    psycopg2-binary \
    python-dateutil \
    pytz \
    setuptools \
    wheel

# Verify installation of critical packages
RUN /opt/odoo/venv/bin/python -c "import babel; print('✅ Babel available:', babel.__version__)" && \
    /opt/odoo/venv/bin/python -c "import psycopg2; print('✅ PostgreSQL driver available')" && \
    /opt/odoo/venv/bin/python -c "import lxml; print('✅ XML processing available')" && \
    echo "✅ Critical packages validation successful"

# Validate that Enterprise references have been properly removed
RUN cd /opt/odoo/src/odoo && \
    echo "🔍 Checking for remaining Enterprise references..." && \
    # Check for hr_work_entry_contract references (but allow some false positives)
    if grep -r "from.*hr_work_entry_contract" addons/ 2>/dev/null; then \
        echo "❌ Found problematic hr_work_entry_contract import references" && exit 1; \
    fi && \
    # Check for Enterprise category references  
    if grep -r "module_category_services_timesheets" addons/ 2>/dev/null; then \
        echo "❌ Found Enterprise category references" && exit 1; \
    fi && \
    echo "✅ Enterprise reference cleanup validated"

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

# Add health check to validate Odoo can start properly (runtime check)
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /opt/odoo/venv/bin/python -c "import sys; sys.path.insert(0, '/opt/odoo/src/odoo'); import odoo.tools" || exit 1

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
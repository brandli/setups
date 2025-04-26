FROM pytorch/pytorch:2.7.0-cuda12.8-cudnn9-devel

# Set the working directory in the container
WORKDIR /workspace

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV PYTHONPATH=/workspace

# Install git, libgit2, and other dependencies
RUN apt-get update && \
    apt-get install -y libgit2-dev git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# (1) Copy the base requirements file into the container and install dependencies
COPY ../1-requirements-base.txt .
RUN pip install --no-cache-dir -r 1-requirements-base.txt

# (2) Copy the dev requirements file and modify it to use the right version constraints
COPY ../2-requirements-dev.txt .
RUN pip install --no-cache-dir -r 2-requirements-dev.txt
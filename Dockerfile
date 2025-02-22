FROM pytorch/pytorch:2.0.0-cuda11.7-cudnn8-devel

# Set the working directory in the container
WORKDIR /workspace
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8
ENV PYTHONPATH /workspace

# Copy the requirements file into the container
COPY ../requirements.txt .

# Install the Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Install kubectl to interface with the SLURM cluster
RUN apt-get update && \
    apt-get install -y curl && \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/

# Copy the actual code
COPY . /workspace

# Command to run your application
CMD ["python", "start.py"]
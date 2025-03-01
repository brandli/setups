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

# Install git
RUN apt-get update && \
    apt-get install -y git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Add your alias to .bashrc
RUN echo 'alias slinky="kubectl --namespace=slurm exec -it statefulsets/slurm-controller -- bash --login"' >> ~/.bashrc

# Copy the actual code
COPY . /workspace

# Command to run your application
CMD ["python", "start.py"]
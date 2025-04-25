# Setups

Set of setups used for CI &amp; training

## Usage

- Build the Docker image: `docker build -t ghcr.io/brandli/my_image:latest .` (replace "my_image" with the name of your branch)
- Make sure you are logged into github
- Push to github: `docker push ghcr.io/brandli/my_image:latest`
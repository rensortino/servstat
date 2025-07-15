
# Use a Python image with uv pre-installed
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim

# Set the working directory to /app
WORKDIR /app
SHELL ["/bin/bash", "-c"]

# Copy the current directory contents into the container at /app
COPY . /app

RUN uv venv
RUN source .venv/bin/activate
RUN uv pip install -r requirements.txt

# Run the backend Python script when the container launches
CMD ["uv", "run", "main.py", "--host", "0.0.0.0", "--port", "9989"]
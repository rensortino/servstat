FROM nvidia/cuda:12.4.1-base-ubuntu22.04

# Set a non-interactive frontend for package installers to avoid prompts
ARG DEBIAN_FRONTEND=noninteractive

# Step 2: Install Python 3.12, pip, and curl.
# The CUDA image doesn't have the specific Python version or uv pre-installed.
# We use the 'deadsnakes' PPA for recent Python versions on Ubuntu.
RUN apt-get update && apt-get install -y \
    software-properties-common \
    curl \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y \
    python3.12 \
    python3-pip \
    python3.12-venv \
    && rm -rf /var/lib/apt/lists/*

# Step 2.5: Rebuild the dynamic linker's cache.
# This makes the container aware of all libraries, including the NVIDIA ones.
RUN ldconfig

# Step 3: Install 'uv', the fast Python package manager from your original image.
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
# Add uv to the PATH
ENV PATH="/root/.local/bin:$PATH"

# Set the working directory to /app
WORKDIR /app
SHELL ["/bin/bash", "-c"]

# Copy your application code into the container
COPY . /app

# Step 4: Create the virtual environment and install dependencies using uv.
# This combines multiple commands into one RUN layer for efficiency.
# Running `uv pip install` from within the venv ensures packages are installed correctly.
RUN uv venv --python 3.12 && \
    source .venv/bin/activate && \
    uv pip install -r requirements.txt

# Step 5: Run the backend Python script when the container launches.
# This command remains the same. `uv run` will automatically use the .venv.
CMD ["uv", "run", "python", "main.py", "--host", "0.0.0.0", "--port", "9989"]
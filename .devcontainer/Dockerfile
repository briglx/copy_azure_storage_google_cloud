FROM mcr.microsoft.com/devcontainers/python:3.10-bullseye

RUN apt-get update && apt-get install -y --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        shellcheck \
        unzip \
        vim \
    && rm -rf /var/lib/apt/lists/*

# Installing Node
SHELL ["/bin/bash", "--login", "-i", "-c"]
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
RUN source /root/.bashrc && nvm install v18.17.0 && npm init -y
SHELL ["/bin/bash", "--login", "-c"]

# Install Azure CLI latest (2.51.0)
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install Azure Function Core Tools 4.0
COPY ./scripts/install_az_func_core_tools.sh .
RUN ./install_az_func_core_tools.sh

# Install Google Cloud CLI
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg  add - && apt-get update -y && apt-get install google-cloud-cli -y

# Install bicep
RUN az bicep install

# Helpful aliases
RUN echo 'alias ll='"'"'ls $LS_OPTIONS -al'"'"'' >> /etc/bash.bashrc

# Install Python requirements
RUN python -m pip install --upgrade pip
COPY ./functions/requirements.txt .
COPY ./functions/requirements_dev.txt .
RUN python -m pip install -r ./requirements_dev.txt

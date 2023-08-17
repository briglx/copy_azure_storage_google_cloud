FROM mcr.microsoft.com/devcontainers/python:3.10-bullseye

RUN apt-get -y update && apt-get install -y ca-certificates curl apt-transport-https lsb-release gnupg vim unzip

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

# Copy requirements.txt
COPY ./functions/requirements.txt .

# Install requirements.txt
RUN pip3 install -r requirements.txt

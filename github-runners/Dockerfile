# base
FROM ubuntu:24.04

# Set the github runner version - check for latest releases https://github.com/actions/runner/releases
ARG RUNNER_VERSION="2.328.0"
ARG RUNNER_USER="docker"
ARG RUNNER_HOME="/home/${RUNNER_USER}"

# Update base packages, add a non-sudo user, and install dependencies in a single layer
RUN apt-get update -y && \
    apt-get upgrade -y && \
    useradd -m ${RUNNER_USER} && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    curl \
    jq \
    build-essential \
    libssl-dev \
    libffi-dev \
    python3 \
    python3-venv \
    python3-dev \     
    python3-pip \      
    libicu74 \
    ca-certificates \
    gnupg \
    lsb-release \
    sudo \
    wget \
    openjdk-21-jdk \
    && rm -rf /var/lib/apt/lists/* && \
    echo "${RUNNER_USER} ALL=(ALL) NOPASSWD: /bin/chmod" >> /etc/sudoers

# Set JAVA_HOME
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# Install Maven 3.9.12
ARG MAVEN_VERSION="3.9.12"
RUN cd /opt && \
    wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 3 \
    https://dlcdn.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz || \
    wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 3 \
    https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz && \
    tar xzf apache-maven-${MAVEN_VERSION}-bin.tar.gz && \
    rm apache-maven-${MAVEN_VERSION}-bin.tar.gz && \
    ln -s /opt/apache-maven-${MAVEN_VERSION} /opt/maven

ENV PATH="/opt/maven/bin:${PATH}"

# Install Docker
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update -y && \
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin && \
    rm -rf /var/lib/apt/lists/* && \
    usermod -aG docker ${RUNNER_USER}

# Set the working directory for the runner user
WORKDIR ${RUNNER_HOME}

# Download and unzip the github actions runner
# Running as root before switching to the final user
RUN mkdir actions-runner && \
    cd actions-runner && \
    curl -O -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz && \
    tar xzf ./actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz && \
    rm ./actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

# Install runner dependencies
RUN ./actions-runner/bin/installdependencies.sh

# Copy over the start.sh script
COPY start.sh .

# Change ownership of the runner home directory and make the script executable
RUN chown -R ${RUNNER_USER}:${RUNNER_USER} ${RUNNER_HOME} && \
    chmod +x ./start.sh

# Switch to the non-root user
USER ${RUNNER_USER}

# Set the entrypoint to the start.sh script, which is now in the WORKDIR
ENTRYPOINT ["./start.sh"]


#Auto remover o runnig após o encerramento do container

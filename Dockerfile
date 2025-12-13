FROM --platform=linux/amd64 debian:12.11

ENV DEBIAN_FRONTEND=noninteractive

ARG CHROME_DRIVER_VERSION=$(curl -s chromedriver.storage.googleapis.com/LATEST_RELEASE)

# Configure apt and install packages
RUN apt-get update \
    && apt-get -y install --no-install-recommends apt-utils libc-bin dialog \
    && apt-get install -y bash-completion git openssh-client less curl fd-find wget \
    python3-dev python3-pip python3-setuptools \
    procps unzip apt-transport-https ca-certificates gnupg-agent software-properties-common \
    nano zip crudini graphviz jq vim lsb-release rsync wget sudo \
    xvfb libxi6 libgconf-2-4 jq libjq1 libonig5 libxkbcommon0 libxss1 libglib2.0-0 libnss3 \
    libfontconfig1 libatk-bridge2.0-0 libatspi2.0-0 libgtk-3-0 libpango-1.0-0 libgdk-pixbuf2.0-0 libxcomposite1 \
    libxcursor1 libxdamage1 libxtst6 libappindicator3-1 libasound2 libatk1.0-0 libc6 libcairo2 libcups2 libxfixes3 \
    libdbus-1-3 libexpat1 libgcc1 libnspr4 libgbm1 libpangocairo-1.0-0 libstdc++6 libx11-6 libx11-xcb1 libxcb1 libxext6 \
    libxrandr2 libxrender1 gconf-service fonts-liberation libappindicator1 xdg-utils build-essential zlib1g-dev \
    libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev pipx apt-utils groff tk-dev

# Yarn & Groff needed for AWS CLI
RUN curl -sS http://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && sudo apt-key export 86E50310 | sudo gpg --dearmor -o /usr/share/keyrings/yarn.gpg

RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/yarn.gpg] http://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && apt-get update \
    && apt-get install -y yarn

# Install the AWS CLI tools
RUN mkdir -p /tmp/aws \
    && cd /tmp/aws \
    && curl "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && mkdir -p ~/.aws/install \
    && ./aws/install \
    && pip3 install git-remote-codecommit \
    && pip3 install boto3 \
    && pip3 install tabulate \
    # Session manager plugin for SSHing etc
    # Determine the correct plugin for the CPU architecture https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html#install-plugin-debian
    && [ "$(dpkg --print-architecture)" = "arm64" ] && arch="arm64" || arch="64bit" \
    && curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_$arch/session-manager-plugin.deb" -o "/tmp/session-manager-plugin.deb" \
    && dpkg -i /tmp/session-manager-plugin.deb

# Localstack CLI - https://github.com/localstack/localstack (support running AWS services locally)
RUN pipx install --include-deps localstack \
    && pipx install awscli-local

# Locales
RUN apt-get update \
    && apt-get install -y locales \
    && echo "LC_ALL=en_US.UTF-8" >> /etc/environment \
    && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
    && echo "LANG=en_US.UTF-8" > /etc/locale.conf \
    && locale-gen en_US.UTF-8

# GO - https://golang.org/doc/install
RUN curl -sL https://golang.org/dl/go1.22.1.linux-$(dpkg --print-architecture).tar.gz | tar -xz -C /usr/local
ENV PATH=$PATH:/usr/local/go/bin

# Github CLI
RUN sudo mkdir -p -m 755 /etc/apt/keyrings \
    && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && sudo apt update \
    && apt install -y gh

# Poetry
RUN pipx install poetry==1.8.0

# Clean up
RUN apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000

# Create a non-root user to use if preferred - see https://aka.ms/vscode-remote/containers/non-root-user.
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USERNAME

# Starship prompt
RUN curl -fsSL https://starship.rs/install.sh | sh -s -- --yes

# Add sudo support for the non-root user
RUN echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME\
    && chmod 0440 /etc/sudoers.d/$USERNAME

# SSH config
RUN mkdir /home/${USERNAME}/.ssh \
    && echo "Host *\n\tIdentitiesOnly=yes\n\tServerAliveInterval=25" > /home/${USERNAME}/.ssh/config \
    && chown 1000:1000 -R /home/${USERNAME}/.ssh/

# Terraform
RUN wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list \
    && sudo apt update && sudo apt install terraform

# Hub
RUN mkdir -p /home/$USERNAME/.local/share \
    && chown $USERNAME:$USERNAME /home/$USERNAME/.local/share \
    && curl -L https://github.com/github/hub/releases/download/v2.14.2/hub-linux-amd64-2.14.2.tgz -o "/home/$USERNAME/hub-linux-amd64-2.14.2.tgz" \
    && tar -zxvf home/$USERNAME/hub-linux-amd64-2.14.2.tgz -C /home/$USERNAME/.local/share \
    && ln -s  /home/$USERNAME/.local/share/hub-linux-amd64-2.14.2 /home/$USERNAME/.local/share/hub-linux \
    && rm hub-linux-amd64-2.14.2.tgz -f

RUN wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq &&\
    chmod +x /usr/local/bin/yq

# General Update
RUN apt-get upgrade -y


###########################################################################################################################################
# This Dockerfile adds a non-root user with sudo access. Use the "remoteUser"
# property in devcontainer.json to use it. On Linux, the container user's GID/UIDs
# will be updated to match your local UID/GID (when using the dockerFile property).
# See https://aka.ms/vscode-remote/containers/non-root-user for details.
USER vscode

SHELL ["/bin/bash", "-c"]

RUN curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash \
    && export NVM_DIR="$HOME/.nvm" \
    && . "$NVM_DIR/nvm.sh" \
    && . "$NVM_DIR/bash_completion" \
    && nvm install v22.12.0

RUN curl -fsSL https://pyenv.run | bash \
    && export PYENV_ROOT="/home/$USERNAME/.pyenv" \
    && export PATH="$PYENV_ROOT/bin:$PATH" \
    && eval "$(pyenv init -)" \
    && pyenv install 3.11.9 \
    && pyenv global 3.11.9

# installing chrome
RUN CHROME_VERSION=$(curl https://googlechromelabs.github.io/chrome-for-testing/LATEST_RELEASE_STABLE); \
    wget -N https://storage.googleapis.com/chrome-for-testing-public/$CHROME_VERSION/linux64/chrome-linux64.zip -P ~/ && \
    unzip ~/chrome-linux64.zip -d ~/ && \
    rm ~/chrome-linux64.zip && \
    sudo mv -f ~/chrome-linux64 ~/chrome && \
    sudo ln -sf ~/chrome/chrome /usr/local/bin/chrome && \
    sudo chmod +x ~/chrome && \
    rm -rf ~/chrome-linux64

# Installing chromedriver
RUN CHROMEDRIVER_VERSION=$(curl https://googlechromelabs.github.io/chrome-for-testing/LATEST_RELEASE_STABLE); \
    wget -N https://storage.googleapis.com/chrome-for-testing-public/$CHROMEDRIVER_VERSION/linux64/chromedriver-linux64.zip -P ~/ && \
    unzip ~/chromedriver-linux64.zip -d ~/ && \
    rm ~/chromedriver-linux64.zip && \
    sudo mv -f ~/chromedriver-linux64/chromedriver /usr/bin/chromedriver && \
    sudo chown root:root /usr/bin/chromedriver && \
    sudo chmod +x /usr/bin/chromedriver && \
    rm -rf ~/chromedriver-linux64

# Install SdkMan, Maven, java, and wiremock
RUN curl -s "https://get.sdkman.io" | bash \
    && export SDKMAN_DIR="/home/$USERNAME/.sdkman" \
    && source /home/$USERNAME/.sdkman/bin/sdkman-init.sh \
    && sdk update \
    && sdk install maven 3.9.6 \
    && sdk install java 21.0.2-open \
    && mvn dependency:get -DgroupId=org.wiremock -DartifactId=wiremock-standalone -Dversion=3.5.2 \
    && mvn dependency:copy -Dartifact=org.wiremock:wiremock-standalone:3.5.2 -DoutputDirectory=/home/$USERNAME/.local/share/java

COPY --chown=vscode .bashrc /home/$USERNAME/.bashrc
COPY --chown=vscode .bash_aliases /home/$USERNAME/.bash_aliases

RUN sudo pip3 install pre-commit --break-system-packages

ENV DEBIAN_FRONTEND=dialog

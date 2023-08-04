FROM ubuntu:20.04
LABEL maintainer="Ocean Protocol <devops@oceanprotocol.com>"
ENV DEBIAN_FRONTEND=noninteractive 
# Set timezone:
RUN ln -snf /usr/share/zoneinfo/$CONTAINER_TIMEZONE /etc/localtime && echo $CONTAINER_TIMEZONE > /etc/timezone
RUN apt update
#RUN apt install -y curl git ca-certificates curl gnupg lsb-release wget
#RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
#RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
#RUN apt update
#RUN apt-get install -y docker-ce docker-ce-cli containerd.io net-tools
RUN apt install -y curl git ca-certificates gnupg lsb-release wget
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
RUN install kubectl /usr/local/bin/kubectl
#RUN systemctl enable docker.service
#RUN systemctl enable containerd.service
WORKDIR /ocean
COPY ./docker-entrypoint.sh /ocean/
COPY ./deployments/ /ocean/deployments/
COPY ./docker-entrypoint.sh /ocean/
ENTRYPOINT ["/ocean/docker-entrypoint.sh"]



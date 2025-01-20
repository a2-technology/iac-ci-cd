FROM ubuntu:noble-20241118.1 AS install
ARG TF_VERSION

# checksum validation; see https://www.hashicorp.com/trust/security and https://developer.hashicorp.com/well-architected-framework/operational-excellence/verify-hashicorp-binary
RUN apt-get update && apt-get install -y wget gpg gnupg unzip git \
    && wget -qO- https://www.hashicorp.com/.well-known/pgp-key.txt | gpg --import \
    && wget https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip \
    && wget https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_SHA256SUMS \
    && wget https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_SHA256SUMS.sig \
    && gpg --verify terraform_${TF_VERSION}_SHA256SUMS.sig terraform_${TF_VERSION}_SHA256SUMS \
    && grep terraform_${TF_VERSION}_linux_amd64.zip terraform_${TF_VERSION}_SHA256SUMS | sha256sum -c \
    && unzip terraform_${TF_VERSION}_linux_amd64.zip -d /tmp \
    && mv /tmp/terraform /usr/local/bin/terraform \
    && chmod 755 /usr/local/bin/terraform \
    && rm -f terraform_${TF_VERSION}_linux_amd64.zip terraform_${TF_VERSION}_SHA256SUMS terraform_${TF_VERSION}_SHA256SUMS.sig \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /home/ubuntu
COPY . .

RUN terraform fmt --recursive \
    && terraform init \
    && terraform validate \
    && chown ubuntu:ubuntu -R /home/ubuntu

USER ubuntu
FROM registry.access.redhat.com/ubi9/ubi:latest
LABEL maintainer="Antigravity" \
    description="CloudBees CI CasC Toolset"
ENV YQ_VERSION=v4.52.4
ENV WORKDIR_BASE=/work
ARG TARGETARCH="arm64"
# Install system dependencies
RUN yum install -y --allowerasing \
    python3.11 python3.11-pip jq git openssl curl gettext ca-certificates shadow-utils \
    && yum clean all

# Make python3.11 the default python3/pip3 so scripts calling "python3" get genson etc.
RUN alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 \
    && alternatives --install /usr/bin/pip3 pip3 /usr/bin/pip3.11 1

# Install Python packages for CasC validation
RUN pip3.11 install --no-cache-dir \
    genson \
    check-jsonschema

# Install yq (architecture-aware)
RUN if [ "${TARGETARCH}" = "arm64" ]; then \
        YQ_BINARY="yq_linux_arm64"; \
    else \
        YQ_BINARY="yq_linux_amd64"; \
    fi && \
    curl -L "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/${YQ_BINARY}" -o /usr/bin/yq && \
    chmod +x /usr/bin/yq

WORKDIR ${WORKDIR_BASE}

USER 1000
EXPOSE 9000
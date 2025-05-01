FROM debian:12-slim

# Install diagnostic tools following AgencyStack Charter principles
RUN apt-get update && apt-get install -y \
    iputils-ping \
    netcat-openbsd \
    dnsutils \
    mariadb-client \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

CMD ["bash"]

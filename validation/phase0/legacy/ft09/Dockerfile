ARG LEGACY_IMAGE=opencti:phase0-ft09-base
FROM ${LEGACY_IMAGE}
RUN apt-get update && apt-get install -y --no-install-recommends gdb \
    && rm -rf /var/lib/apt/lists/*

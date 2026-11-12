ARG LEGACY_IMAGE=opencti:phase0-ft05-base
FROM ${LEGACY_IMAGE}
RUN apt-get update && apt-get install -y --no-install-recommends rcs \
    && rm -rf /var/lib/apt/lists/*

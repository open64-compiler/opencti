FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash perl ksh gcc g++ make cpio libxml-simple-perl libwww-perl \
    libmailtools-perl libcgi-pm-perl procps time file python3 ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /bin/bash /bin/sh \
    && ln -s /usr/bin/perl /usr/local/bin/perl
COPY legacy-source.tar /opt/legacy-source.tar
RUN mkdir -p /opt/cti /tmp/dTM && tar -xf /opt/legacy-source.tar -C /opt/cti \
    && rm /opt/legacy-source.tar
COPY configure_deployment.py /opt/phase0/configure_deployment.py
RUN python3 /opt/phase0/configure_deployment.py
ENV CTI_HOME=/opt/cti CTI_PERL=/usr/bin/perl CTI_SHELL=/bin/bash
WORKDIR /capture
CMD ["/bin/bash"]

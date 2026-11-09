# syntax=docker/dockerfile:1-labs
## hblink3 v3 (n0mjs710/hblink3) + its dashboard + the legacy twisted parrot
FROM ubuntu:24.04 AS base

ENV TERM="xterm" LANG="C.UTF-8" LC_ALL="C.UTF-8"
ARG TARGETARCH
ARG S6_OVERLAY_VERSION=3.2.3.2 S6_OVERLAY_INST=/src/S6
ARG S6_OVERLAY_ADDRESS=https://github.com/just-containers/s6-overlay/releases/download/v
## n0mjs710/hblink3 main - v3.0.0 predates XLX support, so this is pinned past it
ARG HBLINK_GIT_REF=f9292c24eba1de6172c80ddd29f364b2a92dd271
## lz5pn/HBlink3 - only its playback.py (parrot) is used, v3 archived it
ARG PARROT_GIT_REF=23a260e8def6a118d6cf850954d9d475f1d78177
## optional ubuntu archive mirror (ex: http://azure.archive.ubuntu.com/ubuntu on github amd64 runners)
ARG UBUNTU_MIRROR

## apt updates and adds
RUN if [ -n "${UBUNTU_MIRROR}" ]; then \
        sed -i "s|http://archive.ubuntu.com/ubuntu|${UBUNTU_MIRROR}|g" /etc/apt/sources.list.d/ubuntu.sources ; \
    fi \
    && echo 'Acquire::Retries "5";' > /etc/apt/apt.conf.d/80-retries \
    && echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
    && apt update \
    && apt upgrade -y \
    && apt install -y \
        ca-certificates \
        python3 \
        python3-venv \
        wget \
        xz-utils

############################
###### HBlink install ######
############################

## pulling HBlink3 v3
ADD --keep-git-dir=true https://github.com/n0mjs710/hblink3.git#${HBLINK_GIT_REF} /opt/HBlink3

## core + dashboard share one venv
RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir \
        -r /opt/HBlink3/requirements.txt \
        -r /opt/HBlink3/dashboard/requirements.txt

## the dashboard exits without a config.py - ship the sample, mount over it
RUN cp /opt/HBlink3/dashboard/config_sample.py /opt/HBlink3/dashboard/config.py

############################
###### parrot install ######
############################

## pulling the old HBlink3 for playback.py (talks HBP, so v3 reaches it as an OUTBOUND)
ADD https://github.com/lz5pn/HBlink3.git#${PARROT_GIT_REF} /src/parrot

## twisted pinned to what the 2025 image ran
RUN mv /src/parrot/HBlink3 /opt/parrot \
    && python3 -m venv /opt/parrot-venv \
    && /opt/parrot-venv/bin/pip install --no-cache-dir \
        Twisted==24.3.0 \
        bitarray \
        bitstring \
        dmr_utils3 \
    && mkdir -p /var/log/hblink

#################################
###### s6 overlay install  ######
#################################

## installing the s6_overlay noarch
RUN mkdir -p "${S6_OVERLAY_INST}" \
    && wget "${S6_OVERLAY_ADDRESS}${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" \
        -O "${S6_OVERLAY_INST}/s6-overlay-noarch.tar.xz" \
    && tar -C / -xJf "${S6_OVERLAY_INST}/s6-overlay-noarch.tar.xz"

## installing the s6_overlay arch either arm || amd
RUN if [ "${TARGETARCH}" = "arm64" ]; then \
        wget "${S6_OVERLAY_ADDRESS}${S6_OVERLAY_VERSION}/s6-overlay-aarch64.tar.xz" \
            -O "${S6_OVERLAY_INST}/s6-overlay-aarch64.tar.xz" \
        && tar -C / -xJf "${S6_OVERLAY_INST}/s6-overlay-aarch64.tar.xz" ; \
    elif [ "${TARGETARCH}" = "amd64" ]; then \
        wget "${S6_OVERLAY_ADDRESS}${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz" \
            -O "${S6_OVERLAY_INST}/s6-overlay-x86_64.tar.xz" \
        && tar -C / -xJf "${S6_OVERLAY_INST}/s6-overlay-x86_64.tar.xz" ; \
    else \
        echo "DANGER WILL ROBINSON. UNKNOWN TARGETARCH" \
        && exit 1 ; \
    fi

#####################################
###### s6 overlay config begin ######
#####################################

#### hblink ####

## define hblink as a longrun service
COPY <<EOF /etc/s6-overlay/s6-rc.d/hblink/type
longrun
EOF

## define entrypoint for hblink
COPY --chmod=700 <<EOF /etc/s6-overlay/s6-rc.d/hblink/run
#!/command/with-contenv sh
cd /opt/HBlink3
exec /opt/venv/bin/python bridge.py -c hblink.cfg -r rules.py
EOF

## register hblink as a service for s6
RUN touch /etc/s6-overlay/user-bundles.d/user/contents.d/hblink

#### parrot ####

## define parrot as a longrun service
COPY <<EOF /etc/s6-overlay/s6-rc.d/parrot/type
longrun
EOF

## define entrypoint for parrot
COPY --chmod=700 <<EOF /etc/s6-overlay/s6-rc.d/parrot/run
#!/command/with-contenv sh
cd /opt/parrot
exec /opt/parrot-venv/bin/python playback.py -c playback.cfg
EOF

## register parrot as a service for s6
RUN touch /etc/s6-overlay/user-bundles.d/user/contents.d/parrot

#### dashboard ####

## define dashboard as a longrun service
COPY <<EOF /etc/s6-overlay/s6-rc.d/dashboard/type
longrun
EOF

## define entrypoint for dashboard
COPY --chmod=700 <<EOF /etc/s6-overlay/s6-rc.d/dashboard/run
#!/command/with-contenv sh
cd /opt/HBlink3/dashboard
exec /opt/venv/bin/python server.py
EOF

## register dashboard as a service for s6
RUN touch /etc/s6-overlay/user-bundles.d/user/contents.d/dashboard

#####################
###### cleanup ######
#####################

RUN apt -y autoremove \
    && apt -y clean \
    && rm -rf /tmp/* \
    && rm -rf /var/tmp/* \
    && rm -rf /src

############################
###### exposing ports ######
############################

EXPOSE 8080/tcp

########################
###### entrypoint ######
########################

ENTRYPOINT ["/init"]

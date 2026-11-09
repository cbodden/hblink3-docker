# syntax=docker/dockerfile:1-labs
## hblink3
## pinned to 24.04 - ubuntu:latest is 26.04 and hbmonitor's old jinja2 / markupsafe pins aren't tested there
FROM ubuntu:24.04 AS base

ENV TERM="xterm" LANG="C.UTF-8" LC_ALL="C.UTF-8"
ARG TARGETARCH
ARG HBLINK_INST_DIR=/src/hblink
ARG HBMON_INST_DIR=/src/hbmon
ARG S6_OVERLAY_VERSION=3.2.3.2 S6_OVERLAY_INST=/src/S6
ARG S6_OVERLAY_ADDRESS=https://github.com/just-containers/s6-overlay/releases/download/v
## upstream repos pinned to commits (both are frozen upstream)
ARG HBLINK_GIT_REF=23a260e8def6a118d6cf850954d9d475f1d78177 HBMON_GIT_REF=1bb168d17abc63868d21451dba7def54f3c387d7
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
        curl \
        git \
        libffi-dev \
        libssl-dev \
        python3-distutils-extra \
        python3-twisted \
        python3-bitarray \
        python3-dev \
        python3-pip \
        wget

## making dirs for installs
RUN mkdir -p \
    ${HBLINK_INST_DIR} \
    ${HBMON_INST_DIR} \
    ${S6_OVERLAY_INST}

############################
###### HBlink install ######
############################

## pulling HBlink3 Repo
ADD --keep-git-dir=true https://github.com/lz5pn/HBlink3.git#${HBLINK_GIT_REF} ${HBLINK_INST_DIR}

## pulling HBmonitor Repo
ADD --keep-git-dir=true https://github.com/sp2ong/HBmonitor.git#${HBMON_GIT_REF} ${HBMON_INST_DIR}

## Move HBlink folder
RUN cd /opt \
    && mv ${HBLINK_INST_DIR}/HBlink3/ /opt/

## Install dmr_utils
RUN cd /opt \
    && mv ${HBLINK_INST_DIR}/dmr_utils3/ /opt/

RUN cd /opt/dmr_utils3 \
    && /usr/bin/pip3 install --upgrade . --break-system-packages \
    && /usr/bin/pip3 install --upgrade dmr_utils3 --break-system-packages

## install parrot
RUN cd /opt/HBlink3 \
    && chmod +x playback.py \
    && mkdir /var/log/hblink

## install hbmonitor
RUN cd /opt \
    && mv ${HBMON_INST_DIR}/ /opt/HBmonitor

## autobahn pinned to what the 2025 image ran - newer ones want a cryptography
## that debian's pyopenssl (used by twisted) can't load
RUN cd /opt/HBmonitor \
    && /usr/bin/pip3 install autobahn==24.4.2 --break-system-packages \
    && /usr/bin/pip3 install -r requirements.txt --break-system-packages

#################################
###### s6 overlay install  ######
#################################

## installing the s6_overlay noarch
RUN wget "${S6_OVERLAY_ADDRESS}${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" \
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
exec /usr/bin/python3 /opt/HBlink3/bridge.py
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
exec /usr/bin/python3 /opt/HBlink3/playback.py -c /opt/HBlink3/playback.cfg
EOF

## register parrot as a service for s6
RUN touch /etc/s6-overlay/user-bundles.d/user/contents.d/parrot

#### hbmonitor ####

## define hbmonitor as a longrun service
COPY <<EOF /etc/s6-overlay/s6-rc.d/hbmonitor/type
longrun
EOF

## define entrypoint for hbmonitor
COPY --chmod=700 <<EOF /etc/s6-overlay/s6-rc.d/hbmonitor/run
#!/command/with-contenv sh
exec /usr/bin/python3 /opt/HBmonitor/monitor.py
EOF

## register hbmonitor as a service for s6
RUN touch /etc/s6-overlay/user-bundles.d/user/contents.d/hbmonitor

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
EXPOSE 9000/tcp

########################
###### entrypoint ######
########################

ENTRYPOINT ["/init"]

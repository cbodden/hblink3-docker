## hblink3
# syntax=docker/dockerfile:1-labs
FROM --platform=$BUILDPLATFORM ubuntu:latest AS base

ENV TERM="xterm" LANG="C.UTF-8" LC_ALL="C.UTF-8"
ARG TARGETARCH
ARG HBLINK_INST_DIR=/src/hblink
ARG HBMON_INST_DIR=/src/hbmon
ARG S6_OVERLAY_VERSION=3.2.0.2 S6_OVERLAY_INST=/src/S6
ARG S6_OVERLAY_ADDRESS=https://github.com/just-containers/s6-overlay/releases/download/v

## apt updates and adds
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
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
ADD --keep-git-dir=true https://github.com/lz5pn/HBlink3.git ${HBLINK_INST_DIR}

## pulling HBmonitor Repo
ADD --keep-git-dir=true https://github.com/sp2ong/HBmonitor.git ${HBMON_INST_DIR}

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
    && mv ${HBMON_INST_DIR}/HBmonitor/ /opt/

RUN cd /opt/HBmonitor \
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
RUN touch /etc/s6-overlay/s6-rc.d/user/contents.d/hblink

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
RUN touch /etc/s6-overlay/s6-rc.d/user/contents.d/parrot

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
RUN touch /etc/s6-overlay/s6-rc.d/user/contents.d/hbmonitor

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

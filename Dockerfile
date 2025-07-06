## hblink3
# syntax=docker/dockerfile:1-labs
FROM --platform=$BUILDPLATFORM ubuntu:latest AS base

ENV TERM="xterm" LANG="C.UTF-8" LC_ALL="C.UTF-8"
ARG TARGETARCH
ARG HBLINK_INST_DIR=/src/hblink

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
    ${S6_OVERLAY_INST}

############################
###### HBlink install ######
############################

## pulling HBlink3 Repo
ADD --keep-git-dir=true https://github.com/lz5pn/HBlink3.git#master ${HBLINK_INST_DIR}

## Move folders
RUN cd /opt \
    && mv ${HBLINK_INST_DIR}/HBlink3/ /opt/ \
    && mv ${HBLINK_INST_DIR}/HBmonitor/ /opt/ \
    && mv ${HBLINK_INST_DIR}/dmr_utils3/ /opt/

## Install dmr_utils
RUN cd /opt/dmr_utils3 \
    && /usr/bin/pip3 install --upgrade . --break-system-packages \
    && /usr/bin/pip3 install --upgrade dmr_utils3 --break-system-packages

## in compose
## cd /opt/HBlink3/hblink.cfg
## cd /opt/HBlink3/rules.py

## hblink service
RUN cat <<EOF > /lib/systemd/system/hblink.service
[Unit]
Description=Start HBlink
After=multi-user.target

[Service]
ExecStart=/usr/bin/python3 /opt/HBlink3/bridge.py

[Install]
WantedBy=multi-user.target
EOF

## hblink enable
RUN systemctl daemon-reload \
    systemctl enable hblink

## install parrot
RUN cd /opt/HBlink3 \
    && chmod +x playback.py \
    && mkdir /var/log/hblink

## parrot service
RUN cat <<EOF > /lib/systemd/system/parrot.service
[Unit]
Description=HB bridge all Service
After=network-online.target syslog.target
Wants=network-online.target

[Service]
StandardOutput=null
WorkingDirectory=/opt/HBlink3
RestartSec=3
ExecStart=/usr/bin/python3 /opt/HBlink3/playback.py -c /opt/HBlink3/playback.cfg
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOF

## parrot enable
RUN systemctl daemon-reload \
    systemctl enable parrot.service

## HBmonitor
RUN cd /opt/HBmonitor \
    && /usr/bin/pip3 install setuptools wheel --break-system-packages \
    && /usr/bin/pip3 install -r requirements --break-system-packages \
    && cp utils/hbmon.service /lib/systemd/system/ \
    && systemctl daemon-reload \
    && systemctl enable hbmon

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

EXPOSE 8080
EXPOSE 9000

########################
###### entrypoint ######
########################

ENTRYPOINT ["/init"]

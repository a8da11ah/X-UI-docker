FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive

# x-ui-pro.sh expects a real, booted Linux host: it drives systemctl, cron and
# apt directly. We install systemd itself so the container's PID 1 is a real
# init system, matching what the script assumes on a bare VPS.
RUN apt-get update && apt-get install -y --no-install-recommends \
        systemd systemd-sysv dbus \
        wget curl ca-certificates sudo cron iproute2 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Units that assume real hardware/udev and just fail noisily in a container.
RUN systemctl mask \
        systemd-udevd.service systemd-udevd-kernel.socket systemd-udevd-control.socket \
        systemd-modules-load.service getty.target getty-static.service \
        systemd-tmpfiles-setup-dev.service

COPY install-wrapper.sh /usr/local/bin/install-wrapper.sh
COPY x-ui-pro-install.service /etc/systemd/system/x-ui-pro-install.service

RUN chmod +x /usr/local/bin/install-wrapper.sh \
    && chmod 644 /etc/systemd/system/x-ui-pro-install.service \
    && systemctl enable x-ui-pro-install.service

STOPSIGNAL SIGRTMIN+3

VOLUME ["/sys/fs/cgroup"]

CMD ["/lib/systemd/systemd"]

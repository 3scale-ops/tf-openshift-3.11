#cloud-config
write_files:
    - path: /root/.docker/config.json
      owner: root:root
      permissions: '0600'
      content: |
        {
          "auths": {
            "quay.io": {
              "auth": "${quay_registry_auth}"
            },
            "registry.redhat.io": {
              "auth": "${redhat_registry_auth}"
            }
          }
        }
    - path: /etc/sysconfig/docker-storage-setup
      owner: root:root
      permissions: '0660'
      content: |
        ROOT_SIZE=64G
        DEVS=xvdb
        GROWPART=true
        AUTO_EXTEND_POOL=true
    - path: /etc/NetworkManager/NetworkManager.conf
      owner: root:root
      permissions: '0644'
      content: |
        [keyfile]
        unmanaged-devices=interface-name:veth*
        [main]
        plugins=ifcfg-rh
        [logging]
    - path: /etc/sysconfig/iptables
      owner: root:root
      permissions: '0600'
      content: |
        *filter
        :INPUT ACCEPT [0:0]
        :FORWARD ACCEPT [0:0]
        :OUTPUT ACCEPT [0:0]
        -A OUTPUT -m owner ! --uid-owner root -d 169.254.169.254 -j DROP
        COMMIT
    - path: /etc/sysctl.d/98-disableipv6.conf
      owner: root:root
      permissions: '0600'
      content: |
        net.ipv6.conf.all.disable_ipv6 = 1
        net.ipv6.conf.default.disable_ipv6 = 1
    - path: /etc/logrotate.d/crons
      owner: root:root
      permissions: '0644'
      content: |
        /var/log/crons/atop
        {
            rotate 10
            missingok
            notifempty
            size 1k
            compress
        }
    - path: /etc/systemd/system/lvm-exporter.service
      owner: root:root
      permissions: '0660'
      content: |
        [Unit]
        Description=Docker execution of lvm exporter
        Requires=docker.service
        After=docker.service

        [Service]
        User=root
        Restart=on-failure
        RestartSec=10
        Type=simple
        ExecStartPre=-/usr/bin/docker kill lvm-exporter
        ExecStartPre=-/usr/bin/docker rm lvm-exporter
        ExecStart=/bin/sh -c 'docker run --name=lvm-exporter --privileged=true -p 9080:9080 {{ LVM_EXPORTER_DOCKER_IMAGE }}'
        ExecStop=-/usr/bin/docker stop lvm-exporter

        [Install]
        WantedBy=multi-user.target


runcmd:
  - sysctl -p /etc/sysctl.d/*
  - service NetworkManager restart
  - systemctl enable iptables.service
  - service iptables start
  - systemctl restart systemd-journald.service
  - mkdir /etc/systemd/system/docker.service.wants/
  - ln -s /etc/systemd/system/lvm-exporter.service /etc/systemd/system/docker.service.wants/
  - systemctl daemon-reload
  - sed -i "s/#compress/compress/g" /etc/logrotate.conf
  - mkdir -p /var/log/atop
  - chcon -Rt svirt_sandbox_file_t /var/log/atop
  - ln -s /etc/systemd/system/atop.service /etc/systemd/system/docker.service.wants/
  - systemctl enable docker
  - systemctl daemon-reload
  - sleep 30 && systemctl restart --no-block docker

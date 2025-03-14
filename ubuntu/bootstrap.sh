#!/bin/bash

/debootstrap/debootstrap --second-stage

# Remount /proc, as debootstrap umounts it
mount -t proc proc $ROOTFS/proc


# Update sources
cat >/etc/apt/sources.list <<EOF
deb $DISTRO_URL $DISTRO main restricted
deb $DISTRO_URL $DISTRO-updates main restricted

deb $DISTRO_URL $DISTRO universe
deb $DISTRO_URL $DISTRO-updates universe

#deb $DISTRO_URL $DISTRO multiverse
#deb $DISTRO_URL $DISTRO-updates multiverse

#deb $DISTRO_URL $DISTRO-backports main restricted universe multiverse

deb $DISTRO_URL $DISTRO-security main restricted
deb $DISTRO_URL $DISTRO-security universe
deb $DISTRO_URL $DISTRO-security multiverse
EOF


# update and install some packages
apt update
apt install --no-install-recommends -y util-linux haveged openssh-server systemd kmod \
                                       initramfs-tools conntrack ebtables ethtool iproute2 \
                                       iptables mount socat ifupdown iputils-ping vim dhcpcd5 \
                                       neofetch sudo chrony wget net-tools joe less

# optional zram
apt install -y zram-config
systemctl enable zram-config

# Create base config files
mkdir -p /etc/network
cat >>/etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto end0
iface end0 inet dhcp

EOF

cat >/etc/resolv.conf <<EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

# set hostname
echo $DISTRO_HOSTNAME > /etc/hostname

# enable root login through ssh
sed -i "s/#PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config

# set root passwd
echo "root:$ROOTPW" | chpasswd

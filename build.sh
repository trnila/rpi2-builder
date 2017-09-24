#!/bin/bash
set -e
IMAGE=image.img
ZIP=image.zip
KEY=~/.ssh/id_rsa.pub

if [ ! -f "$IMAGE" ]; then
	if [ ! -f "$ZIP" ]; then
		wget https://downloads.raspberrypi.org/raspbian_lite_latest -O "$ZIP"
	fi
	unzip -o "$ZIP"
	mv "$(unzip -Z1 $ZIP)" "$IMAGE"
fi

function cleanup() {
	sudo umount mnt/boot
	sudo umount mnt
	sudo losetup -d "$dev"
}

trap cleanup EXIT

mkdir -p mnt

dev=$(sudo losetup -f --show -P "$IMAGE")
sudo mount "${dev}p2" mnt
sudo mount "${dev}p1" mnt/boot

sudo rsync -rv files/. mnt/.
sudo cp /usr/bin/qemu-arm-static mnt/usr/bin/

if [ -f $KEY ]; then
	mkdir -p mnt/home/pi/.ssh
	cp $KEY mnt/home/pi/.ssh/authorized_keys
	cat << EOF | sudo chroot mnt qemu-arm-static /bin/bash
		source /etc/profile
		systemctl enable ssh || true
EOF
fi


cat << EOF | sudo chroot mnt qemu-arm-static /bin/bash
	source /etc/profile
	apt install -y git vim
	if [ ! -d /home/pi/app/.git ]; then
		git clone https://github.com/trnila/rpi2-amp.git /home/pi/app
	fi
	chown -R pi:pi /home/pi
	apt-get clean
EOF

sudo rm mnt/usr/bin/qemu-arm-static
sync

sudo dd if=/dev/zero of=mnt/zero || true
sudo rm mnt/zero
sudo umount mnt/boot mnt
sudo zerofree -v "${dev}p2"

du -sh "$IMAGE"
echo "Image is built"
echo "Copy to your sd card with"
echo " sudo dd if=$IMAGE of=/dev/mmcblk0 conv=fsync status=progress bs=4M"

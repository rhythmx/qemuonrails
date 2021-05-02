install -o root -m 0644 qemu@.service /etc/systemd/system/qemu@.service
install -d -o root -m 755 /etc/qemu
install -d -o root -m 755 /etc/qemu/lib
for f in *.sh; do
	if [ "$f" != "install.sh" ]; then
		install -o root -m 0744 "$f" /etc/qemu/
	fi
done
install -o root -m 644 lib/qemuonrails.sh /etc/qemu/lib/

#!/bin/sh
# Derived from https://github.com/fitu996/overlayRoot.sh
# Original license: GPLv3
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

loglevel="4"
write_log(){
    [ "$loglevel" -lt "$1" ] || echo "[overlayRoot.sh]" "$2"
}
fail(){
        write_log 2 "$1"
        write_log 2 "$1 there is something wrong with overlayRoot.sh."
        exec /bin/sh
}

UPPER_SIZE="400M"

if [ -f /etc/overlayroot.conf ]; then
    . /etc/overlayroot.conf
fi

for x in $(cat /proc/cmdline); do
    if [ "x$x" = "xnoOverlayRoot" ] ; then
        write_log 6 "overlayRoot is disabled. continue init process."
        exec /sbin/init "$@"
    fi
done

write_log 5 "starting overlayRoot..."

modprobe overlay || :

mount -t tmpfs none /mnt || fail "ERROR: kernel missing tmpfs functionality"

mkdir -p /mnt/lower /mnt/overlay/upper /mnt/overlay/work /mnt/newroot

mount -t overlay -o lowerdir=/mnt/lower,upperdir=/mnt/overlay/upper,workdir=/mnt/overlay/work overlayfs-root /mnt/newroot || \
    fail "ERROR: kernel missing overlay functionality"

umount /mnt/newroot
umount /mnt

mount -t tmpfs inittemp /mnt || fail "ERROR: could not create tempfs"
mkdir /mnt/lower
mkdir /mnt/overlay

mount -t tmpfs root-rw -o size=$UPPER_SIZE /mnt/overlay || \
    fail "ERROR: could not create tmpfs for upper filesystem"

mkdir /mnt/overlay/upper
mkdir /mnt/overlay/work
mkdir /mnt/newroot

rootDev="/dev/disk/by-label/root"
rootMountOpt="ro"
rootFsType="ext4"

if blkid "$rootDev"; then
    :
else
    rootDev="/dev/disk/by-label/rootfs"
    if ! blkid "$rootDev"; then
        fail "could not find root filesystem device"
    fi
fi

mount -t "${rootFsType}" -o "${rootMountOpt}" "${rootDev}" /mnt/lower || \
    fail "ERROR: could not ro-mount original root partition"

mount -t overlay -o lowerdir=/mnt/lower,upperdir=/mnt/overlay/upper,workdir=/mnt/overlay/work overlayfs-root /mnt/newroot || \
    fail "ERROR: could not mount overlayFS"

mkdir /mnt/newroot/lower
mkdir /mnt/newroot/overlay

cp /mnt/lower/etc/fstab /mnt/newroot/etc/fstab.orig

cat > /mnt/newroot/etc/fstab << 'EOF'
# /etc/fstab - static file system information
# 
# <file system>           <mount point>   <type>  <options>       <dump>  <pass>

/dev/disk/by-label/root   /               ext4    ro              0       0
tmpfs                     /tmp            tmpfs   size=400M       0       0
tmpfs                     /var            tmpfs   size=100M       0       0
EOF

cd /mnt/newroot
pivot_root . mnt

exec chroot . sh -c "
mount --move /mnt/mnt/lower/ /lower || \
    fail 'ERROR: could not move ro-root into newroot'
mount --move /mnt/mnt/overlay /overlay || \
    fail 'ERROR: could not move tempfs rw mount into newroot'
chmod 755 /overlay
mount --move /mnt/proc /proc || \
    fail 'ERROR: could not move proc mount into newroot'
mount --move /mnt/dev /dev || :
mount | grep -E '^/mnt' | sort -r | while read xx; do
    mp=\$(echo \"\$xx\" | sed 's/^.* on //g' | sed 's/ type .*\$//g')
    umount \"\$mp\" 2>/dev/null || true
done
exec /sbin/init \"\$@\"
" sh "$@"

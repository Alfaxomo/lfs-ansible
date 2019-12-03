#!/bin/bash

## this must be run as the root user

LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$( uname -m )-lfs-linux-gnu
lfs=/mnt/lfs
lfs_src=/mnt/lfs/sources

_chroot() {

  mkdir -pv $LFS/{dev,proc,sys,run}
  mknod -m 600 $LFS/dev/console c 5 1
  mknod -m 666 $LFS/dev/null c 1 3
  mount -v --bind /dev $LFS/dev
  mount -vt devpts devpts $LFS/dev/pts -o gid=5,mode=620
  mount -vt proc proc $LFS/proc
  mount -vt sysfs sysfs $LFS/sys
  mount -vt tmpfs tmpfs $LFS/run
  if [ -h $LFS/dev/shm ]; then
    mkdir -pv $LFS/$(readlink $LFS/dev/shm)
  fi

  #chroot "$LFS" /tools/bin/env -i \
  #    HOME=/root                  \
  #    TERM="$TERM"                \
  #    PS1='(lfs chroot) \u:\w\$ ' \
  #    PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin \
  #    /tools/bin/bash --login +h

}

_creatingdirectories() {

  mkdir -pv /{bin,boot,etc/{opt,sysconfig},home,lib/firmware,mnt,opt}
  mkdir -pv /{media/{floppy,cdrom},sbin,srv,var}
  install -dv -m 0750 /root
  install -dv -m 1777 /tmp /var/tmp
  mkdir -pv /usr/{,local/}{bin,include,lib,sbin,src}
  mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man}
  mkdir -v  /usr/{,local/}share/{misc,terminfo,zoneinfo}
  mkdir -v  /usr/libexec
  mkdir -pv /usr/{,local/}share/man/man{1..8}
  mkdir -v  /usr/lib/pkgconfig

  case $(uname -m) in
   x86_64) mkdir -v /lib64 ;;
  esac

  mkdir -v /var/{log,mail,spool}
  ln -sv /run /var/run
  ln -sv /run/lock /var/lock
  mkdir -pv /var/{opt,cache,lib/{color,misc,locate},local}

}

#_chroot
_creatingdirectories

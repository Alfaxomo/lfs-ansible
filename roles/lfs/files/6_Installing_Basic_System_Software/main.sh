#!/bin/bash

## This must all be run within the chroot i.e. after the steps in this doc
### http://www.linuxfromscratch.org/lfs/view/stable/chapter06/chroot.html

SRC=/sources

_creatingdirs() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/creatingdirs.html

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

_createfiles() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/createfiles.html

  ln -sv /tools/bin/{bash,cat,chmod,dd,echo,ln,mkdir,pwd,rm,stty,touch} /bin
  ln -sv /tools/bin/{env,install,perl,printf}         /usr/bin
  ln -sv /tools/lib/libgcc_s.so{,.1}                  /usr/lib
  ln -sv /tools/lib/libstdc++.{a,so{,.6}}             /usr/lib
  ln -sv bash /bin/sh
  ln -sv /proc/self/mounts /etc/mtab

cat > /etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/bin/false
daemon:x:6:6:Daemon User:/dev/null:/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/var/run/dbus:/bin/false
nobody:x:99:99:Unprivileged User:/dev/null:/bin/false
EOF

cat > /etc/group << "EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
usb:x:14:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
input:x:24:
mail:x:34:
kvm:x:61:
wheel:x:97:
nogroup:x:99:
users:x:999:
EOF

  exec /tools/bin/bash --login +h

  touch /var/log/{btmp,lastlog,faillog,wtmp}
  chgrp -v utmp /var/log/lastlog
  chmod -v 664  /var/log/lastlog
  chmod -v 600  /var/log/btmp

}
_
_linux_headers() {
# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/linux-headers.html

  linux_source=$( find $SRC -name linux*.tar.xz )
  linux=${linux_source%.tar.xz}
 
  cd "${SRC}" && \
  tar -vxf "${linux_source}"

  cd "${linux}" && \
  make mrproper && \
  make -j4 INSTALL_HDR_PATH=dest headers_install && \
  find dest/include \( -name .install -o -name ..install.cmd \) -delete && \
  cp -rv dest/include/* /usr/include

  rm -Rf "${linux}"

}

_man_pages() {
# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/man-pages.html

  man_source=$( find $SRC -name man-pages*.tar.xz )
  man=${man_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${man_source}"

  cd "${man}" && \
  make -j4 install

  rm -Rf "${man}"

}

_glibc() {
# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/glibc.html

  glibc_source=$( find $SRC -name glibc*.tar.xz )
  glibc=${glibc_source%.tar.xz}
  build="${glibc}/build"

  cd "${SRC}" && \
  tar -vxf "${glibc_source}"

  cd "${glibc}" && \
  patch -Np1 -i ../glibc-2.30-fhs-1.patch && \
  sed -i '/asm.socket.h/a# include <linux/sockios.h>' \
     sysdeps/unix/sysv/linux/bits/socket.h

  cd "${glibc}" && \
  case $(uname -m) in
      i?86)   ln -sfv ld-linux.so.2 /lib/ld-lsb.so.3
      ;;
      x86_64) ln -sfv ../lib/ld-linux-x86-64.so.2 /lib64
              ln -sfv ../lib/ld-linux-x86-64.so.2 /lib64/ld-lsb-x86-64.so.3
     ;;
  esac

  cd "${glibc}" && \
  mkdir -v build

  cd "${build}" && \
  CC="gcc -ffile-prefix-map=/tools=/usr" \
  ../configure --prefix=/usr                          \
               --disable-werror                       \
               --enable-kernel=3.2                    \
               --enable-stack-protector=strong        \
               --with-headers=/usr/include            \
               libc_cv_slibdir=/lib

  cd "${build}" && \
  make -j4

  cd "${build}" && \
  case $(uname -m) in
    i?86)   ln -sfnv $PWD/elf/ld-linux.so.2        /lib ;;
    x86_64) ln -sfnv $PWD/elf/ld-linux-x86-64.so.2 /lib ;;
  esac

  cd "${build}" && \
  touch /etc/ld.so.conf && \
  sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile

  cd "${build}" && \
  make -j4 install

  cd "${build}" && \
  cp -v ../nscd/nscd.conf /etc/nscd.conf && \
  mkdir -pv /var/cache/nscd

  cd "${build}" && \
  mkdir -pv /usr/lib/locale && \
  localedef -i POSIX -f UTF-8 C.UTF-8 2> /dev/null || true && \
  localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8 && \
  localedef -i de_DE -f ISO-8859-1 de_DE && \
  localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro && \
  localedef -i de_DE -f UTF-8 de_DE.UTF-8 && \
  localedef -i el_GR -f ISO-8859-7 el_GR && \
  localedef -i en_GB -f UTF-8 en_GB.UTF-8 && \
  localedef -i en_HK -f ISO-8859-1 en_HK && \
  localedef -i en_PH -f ISO-8859-1 en_PH && \
  localedef -i en_US -f ISO-8859-1 en_US && \
  localedef -i en_US -f UTF-8 en_US.UTF-8 && \
  localedef -i es_MX -f ISO-8859-1 es_MX && \
  localedef -i fa_IR -f UTF-8 fa_IR && \
  localedef -i fr_FR -f ISO-8859-1 fr_FR && \
  localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro && \
  localedef -i fr_FR -f UTF-8 fr_FR.UTF-8 && \
  localedef -i it_IT -f ISO-8859-1 it_IT && \
  localedef -i it_IT -f UTF-8 it_IT.UTF-8 && \
  localedef -i ja_JP -f EUC-JP ja_JP && \
  localedef -i ja_JP -f SHIFT_JIS ja_JP.SIJS 2> /dev/null || true && \
  localedef -i ja_JP -f UTF-8 ja_JP.UTF-8 && \
  localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R && \
  localedef -i ru_RU -f UTF-8 ru_RU.UTF-8 && \
  localedef -i tr_TR -f UTF-8 tr_TR.UTF-8 && \
  localedef -i zh_CN -f GB18030 zh_CN.GB18030 && \
  localedef -i zh_HK -f BIG5-HKSCS zh_HK.BIG5-HKSCS

  cd "${build}" && \
  make -j4 localedata/install-locales

cat > /etc/nsswitch.conf << "EOF"
# Begin /etc/nsswitch.conf

passwd: files
group: files
shadow: files

hosts: files dns
networks: files

protocols: files
services: files
ethers: files
rpc: files
 
# End /etc/nsswitch.conf
EOF

  cd "${build}" && \
  tar -xf ../../tzdata2019b.tar.gz && \
  ZONEINFO=/usr/share/zoneinfo && \
  mkdir -pv $ZONEINFO/{posix,right}
  
  cd "${build}" && \
  for tz in etcetera southamerica northamerica europe africa antarctica  \
            asia australasia backward pacificnew systemv; do
      zic -L /dev/null   -d $ZONEINFO       ${tz}
      zic -L /dev/null   -d $ZONEINFO/posix ${tz}
      zic -L leapseconds -d $ZONEINFO/right ${tz}
  done

  cd "${build}" && \
  cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO && \
  zic -d $ZONEINFO -p America/New_York && \
  unset ZONEINFO

  cd "${build}" && \
  ln -sfv /usr/share/zoneinfo/Canada/Eastern /etc/localtime

cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib
EOF

cat >> /etc/ld.so.conf << "EOF"
# Add an include directory
include /etc/ld.so.conf.d/*.conf
EOF

  mkdir -pv /etc/ld.so.conf.d

  rm -Rf "{glibc}"

}

_adjusting_toolchain() {
# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/adjusting.html

  mv -v /tools/bin/{ld,ld-old}
  mv -v /tools/$(uname -m)-pc-linux-gnu/bin/{ld,ld-old}
  mv -v /tools/bin/{ld-new,ld}
  ln -sv /tools/bin/ld /tools/$(uname -m)-pc-linux-gnu/bin/ld

  gcc -dumpspecs | sed -e 's@/tools@@g'                   \
      -e '/\*startfile_prefix_spec:/{n;s@.*@/usr/lib/ @}' \
      -e '/\*cpp:/{n;s@$@ -isystem /usr/include@}' >      \
      `dirname $(gcc --print-libgcc-file-name)`/specs

  echo 'int main(){}' > dummy.c
  cc dummy.c -v -Wl,--verbose &> dummy.log
  readelf -l a.out | grep ': /lib'

  grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log && \
  #/usr/lib/../lib/crt1.o succeeded
  #/usr/lib/../lib/crti.o succeeded
  #/usr/lib/../lib/crtn.o succeeded
  grep -B1 '^ /usr/include' dummy.log && \
  ##include <...> search starts here:
  # /usr/include
  grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g' && \
  #SEARCH_DIR("/usr/lib")
  #SEARCH_DIR("/lib")
  grep "/lib.*/libc.so.6 " dummy.log && \
  #attempt to open /lib/libc.so.6 succeeded
  grep found dummy.log
  #found ld-linux-x86-64.so.2 at /lib/ld-linux-x86-64.so.2

  rm -v dummy.c a.out dummy.log

}

_zlib() {
# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/zlib.html

  zlib_source=$( find $SRC -name zlib*.tar.xz )
  zlib=${zlib_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${zlib_source}"

  cd "${zlib}" && \
  ./configure --prefix=/usr && \
  make -j4 && \
  make -j4 install

  cd "${zlib}" && \
  mv -v /usr/lib/libz.so.* /lib && \
  ln -sfv ../../lib/$(readlink /usr/lib/libz.so) /usr/lib/libz.so

  rm -Rf "${zlib}"

}

_file () {
# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/file.html

  file_source=$( find $SRC -name file*.tar.gz )
  file=${file_source%.tar.gz}

  cd "${SRC}" && \
  tar -vxf "${file_source}"

  cd "${file}" && \
  ./configure --prefix=/usr && \
  make -j4 && \
  make -j4 install

  rm -Rf "${file}"

}

_readline() {
# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/readline.html

  readline_source=$( find $SRC -name readline*.tar.gz )
  readline=${readline_source%.tar.gz}

  cd "${SRC}" && \
  tar -vxf "${readline_source}"

  cd "${file}" && \
  sed -i '/MV.*old/d' Makefile.in && \
  sed -i '/{OLDSUFF}/c:' support/shlib-install

  cd "${file}" && \
  ./configure --prefix=/usr    \
              --disable-static \
              --docdir=/usr/share/doc/readline-8.0

  cd "${file}" && \
  make -j4 SHLIB_LIBS="-L/tools/lib -lncursesw" && \
  make -j4 SHLIB_LIBS="-L/tools/lib -lncursesw" install

  cd "${file}" && \
  mv -v /usr/lib/lib{readline,history}.so.* /lib && \
  chmod -v u+w /lib/lib{readline,history}.so.* && \
  ln -sfv ../../lib/$(readlink /usr/lib/libreadline.so) /usr/lib/libreadline.so && \
  ln -sfv ../../lib/$(readlink /usr/lib/libhistory.so ) /usr/lib/libhistory.so

  rm -Rf "${readline}"

}

_m4() {
# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/m4.html

  m4_source=$( find $SRC -name m4*.tar.xz )
  m4=${m4_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${m4_source}"

  cd "${m4}" && \
  sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' lib/*.c && \
  echo "#define _IO_IN_BACKUP 0x100" >> lib/stdio-impl.h

  cd "${m4}" && \
  ./configure --prefix=/usr && \
  make -j4 && \
  make -j4 install

  rm -Rf "${m4}"

}

_bc() {
# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/bc.html

  bc_source=$( find $SRC -name bc*.tar.gz )
  bc=${bc_source%.tar.gz}

  cd "${SRC}" && \
  tar -vxf "${bc_source}"

  cd "${bc}" && \
  PREFIX=/usr CC=gcc CFLAGS="-std=c99" ./configure.sh -G -O3 && \
  make -j4 && \
  make -j4 install

  rm -Rf "${bc}"

}

_binutils() {
# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/binutils.html

  binutils_source=$( find $SRC -name binutils*.tar.xz )
  binutils=${binutils_source%.tar.xz}
  build="${binutils}/build"

  cd "${SRC}" && \
  tar -vxf "${binutils_source}"

  cd "${binutils}" && \
  expect -c "spawn ls"
  # spawn ls

  cd "${binutils}" && \
  sed -i '/@\tincremental_copy/d' gold/testsuite/Makefile.in

  cd "${binutils}" && \
  mkdir -v build

  cd "${build}" && \
  ../configure --prefix=/usr       \
               --enable-gold       \
               --enable-ld=default \
               --enable-plugins    \
               --enable-shared     \
               --disable-werror    \
               --enable-64-bit-bfd \
               --with-system-zlib 

  cd "${build}" && \
  make -j4 tooldir=/usr && \
  make -j4 tooldir=/usr install

  rm -Rf "${binutils}"

}

_gmp() {
# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/gmp.html

  gmp_source=$( find $SRC -name gmp*.tar.xz )
  gmp=${gmp_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${gmp_source}"

  cd "${gmp}" && \
  ./configure --prefix=/usr    \
              --enable-cxx     \
              --disable-static \
              --docdir=/usr/share/doc/gmp-6.1.2

  cd "${gmp}" && \
  make -j4 && \
  make -j4 html && \
  make -j4 install && \
  make -j4 install-html

  rm -Rf "${gmp}"

}

_mpfr() {
# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/mpfr.html

  mpfr_source=$( find $SRC -name mpfr*.tar.xz )
  mpfr=${mpfr_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${mpfr_source}"

  cd "${mpfr}" && \
  ./configure --prefix=/usr        \
              --disable-static     \
              --enable-thread-safe \
              --docdir=/usr/share/doc/mpfr-4.0.2

  cd "${mpfr}" && \
  make -j4 && \
  make -j4 html && \
  make -j4 install && \
  make -j4 install-html

  rm -Rf "${mpfr}"

}

_mpc() {
# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/mpc.html

  mpc_source=$( find $SRC -name mpc*.tar.gz )
  mpc=${mpc_source%.tar.gz}

  cd "${SRC}" && \
  tar -vxf "${mpc_source}"

  cd "${mpc}" && \
  ./configure --prefix=/usr    \
              --disable-static \
              --docdir=/usr/share/doc/mpc-1.1.0

  cd "${mpc}" && \
  make -j4 && \
  make -j4 html && \
  make -j4 install && \
  make -j4 install-html

  rm -Rf "${mpc}"

}

_shadow() {
# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/shadow.html

  shadow_source=$( find $SRC -name shadow*.tar.xz )
  shadow=${shadow_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${shadow_source}"

  cd "${shadow}" && \
  sed -i 's/groups$(EXEEXT) //' src/Makefile.in && \
  find man -name Makefile.in -exec sed -i 's/groups\.1 / /'   {} \; && \
  find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \; && \
  find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \;

  cd "${shadow}" && \
  sed -i -e 's@#ENCRYPT_METHOD DES@ENCRYPT_METHOD SHA512@' \
       -e 's@/var/spool/mail@/var/mail@' etc/login.defs

  cd "${shadow}" && \
  sed -i 's/1000/999/' etc/useradd

  cd "${shadow}" && \
  ./configure --sysconfdir=/etc --with-group-name-max-length=32 && \
  make -j4 && \
  make -j4 install && \
  mv -v /usr/bin/passwd /bin

  cd "${shadow}" && \
  pwconv && \
  grpconv

  echo "linuxfromscratch" | passwd root --stdin

  rm -Rf '${shadow}"

}

_gcc() {
# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/gcc.html

  gcc_source=$( find $SRC -name glibc*.tar.xz )
  gcc=${glibc_source%.tar.xz}
  build="${gcc}/build"

  cd "${SRC}" && \
  tar -vxf "${gcc_source}"

  cd "${gcc}" && \
  case $(uname -m) in
    x86_64)
      sed -e '/m64=/s/lib64/lib/' \
          -i.orig gcc/config/i386/t-linux64
    ;;
  esac

  cd "${gcc}" && \
  mkdir -v build

  cd "${build}" && \
  SED=sed                               \
  ../configure --prefix=/usr            \
               --enable-languages=c,c++ \
               --disable-multilib       \
               --disable-bootstrap      \
               --with-system-zlib

  cd "${build}" && \
  make -j4 && \
  ulimit -s 32768 && \
  make -j4 install && \
  rm -rf /usr/lib/gcc/$(gcc -dumpmachine)/9.2.0/include-fixed/bits/

  cd "${build}" && \
  chown -v -R root:root \
      /usr/lib/gcc/*linux-gnu/9.2.0/include{,-fixed}

  cd "${build}" && \
  ln -sv ../usr/bin/cpp /lib && \
  ln -sv gcc /usr/bin/cc && \
  install -v -dm755 /usr/lib/bfd-plugins && \
  ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/9.2.0/liblto_plugin.so \
          /usr/lib/bfd-plugins/

  cd "${build}" && \
  echo 'int main(){}' > dummy.c && \
  cc dummy.c -v -Wl,--verbose &> dummy.log && \
  readelf -l a.out | grep ': /lib'

  rm -v dummy.c a.out dummy.log
  rm -Rf "${gcc}"

  mkdir -pv /usr/share/gdb/auto-load/usr/lib
  mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib

}

_bzip2() {
# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/bzip2.html

  bzip2_source=$( find $SRC -name bzip2*.tar.gz )
  bzip2=${bzip2_source%.tar.gz}

  cd "${SRC}" && \
  tar -vxf "${bzip2_source}"

  cd "${bzip2}" && \
  patch -Np1 -i ../bzip2-1.0.8-install_docs-1.patch && \
  sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile && \
  sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile

  cd "${bzip2}" && \
  make -j4 -f Makefile-libbz2_so && \
  make -j4 clean && \
  make -j4 && \
  make -j4 PREFIX=/usr install

  cd "${bzip2}" && \
  cp -v bzip2-shared /bin/bzip2
  cp -av libbz2.so* /lib
  ln -sv ../../lib/libbz2.so.1.0 /usr/lib/libbz2.so
  rm -v /usr/bin/{bunzip2,bzcat,bzip2}
  ln -sv bzip2 /bin/bunzip2
  ln -sv bzip2 /bin/bzcat

  rm -Rf "${bzip2}"

}

_pkg_config() {
# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/pkg-config.html

  pkg-config_source=$( find $SRC -name pkg-config*.tar.gz )
  pkg-config=${pkg-config_source%.tar.gz}

  cd "${SRC}" && \
  tar -vxf "${pkg-config_source}"

  cd "${pkg-config}" && \
  ./configure --prefix=/usr              \
              --with-internal-glib       \
              --disable-host-tool        \
              --docdir=/usr/share/doc/pkg-config-0.29.2 

  cd "${pkg-config}" && \
  make -j4 && \
  make -j4 install

  rm -Rf "${pkg-config}"

}

_ncurses() {
# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/ncurses.html

  ncurses_source=$( find $SRC -name ncurses*.tar.gz )
  ncurses=${ncurses_source%.tar.gz}

  cd "${SRC}" && \
  tar -vxf "${ncurses_source}"

  cd "${ncurses}" && \
  sed -i '/LIBTOOL_INSTALL/d' c++/Makefile.in

  cd "${ncurses}" && \
  ./configure --prefix=/usr           \
              --mandir=/usr/share/man \
              --with-shared           \
              --without-debug         \
              --without-normal        \
              --enable-pc-files       \
              --enable-widec

  cd "${ncurses}" && \
  make -j4 && \
  make -j4 install

  cd "${ncurses}" && \
  mv -v /usr/lib/libncursesw.so.6* /lib && \
  ln -sfv ../../lib/$(readlink /usr/lib/libncursesw.so) /usr/lib/libncursesw.so

  cd "${ncurses}" && \
  for lib in ncurses form panel menu ; do
      rm -vf                    /usr/lib/lib${lib}.so
      echo "INPUT(-l${lib}w)" > /usr/lib/lib${lib}.so
      ln -sfv ${lib}w.pc        /usr/lib/pkgconfig/${lib}.pc
  done

  cd "${ncurses}" && \
  rm -vf                     /usr/lib/libcursesw.so && \
  echo "INPUT(-lncursesw)" > /usr/lib/libcursesw.so && \
  ln -sfv libncurses.so      /usr/lib/libcurses.so

  rm -Rf "${ncurses}"

}

_attr() {
# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/attr.html

  attr_source=$( find $SRC -name attr*.tar.gz )
  attr=${attr_source%.tar.gz}

  cd "${SRC}" && \
  tar -vxf "${attr_source}"

  cd "${attr}" && \
  ./configure --prefix=/usr     \
              --bindir=/bin     \
              --disable-static  \
              --sysconfdir=/etc \
              --docdir=/usr/share/doc/attr-2.4.48
  
  cd "${attr}" && \
  make -j4 && \
  make -j4 install

  cd "${attr}" && \
  mv -v /usr/lib/libattr.so.* /lib && \
  ln -sfv ../../lib/$(readlink /usr/lib/libattr.so) /usr/lib/libattr.so

  rm -Rf "${attr}"

}

_acl() {
# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/acl.html

  acl_source=$( find $SRC -name acl*.tar.gz )
  acl=${acl_source%.tar.gz}

  cd "${SRC}" && \
  tar -vxf "${acl_source}"

  cd "${acl}" && \
  ./configure --prefix=/usr         \
              --bindir=/bin         \
              --disable-static      \
              --libexecdir=/usr/lib \
              --docdir=/usr/share/doc/acl-2.2.53

  cd "${acl}" && \
  make -j4 && \
  make -j4 install

  cd "${acl}" && \
  mv -v /usr/lib/libacl.so.* /lib && \
  ln -sfv ../../lib/$(readlink /usr/lib/libacl.so) /usr/lib/libacl.so

  rm -Rf "${acl}"

}

_libcap() {
# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/libcap.html

  libcap_source=$( find $SRC -name libcap*.tar.xz )
  libcap=${libcap_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${libcap_source}"

  cd "${libcap}" && \
  sed -i '/install.*STALIBNAME/d' libcap/Makefile

  cd "${libcap}" && \
  make -j4 && \
  make -j4 RAISE_SETFCAP=no lib=lib prefix=/usr install && \
  chmod -v 755 /usr/lib/libcap.so.2.27

  cd "${libcap}" && \
  mv -v /usr/lib/libcap.so.* /lib && \
  ln -sfv ../../lib/$(readlink /usr/lib/libcap.so) /usr/lib/libcap.so

  rm -Rf "${libcap}"

}

_sed() {
# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/sed.html

  sed_source=$( find $SRC -name sed*.tar.xz )
  sed=${sed_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${sed_source}"

  cd "${sed}" && \
  sed -i 's/usr/tools/'                 build-aux/help2man && \
  sed -i 's/testsuite.panic-tests.sh//' Makefile.in

  cd "${sed}" && \
  ./configure --prefix=/usr --bindir=/bin

  cd "${sed}" && \
  make -j4 && \
  make -j4 html && \
  make -j4 install && \
  install -d -m755           /usr/share/doc/sed-4.7 && \
  install -m644 doc/sed.html /usr/share/doc/sed-4.7

  rm -Rf "${sed}"

}

_psmisc() {
# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/psmisc.html

  psmisc_source=$( find $SRC -name psmisc*.tar.xz )
  psmisc=${psmisc_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${psmisc_source}"

  cd "${psmisc}" && \
  ./configure --prefix=/usr && \
  make -j4 && \
  make -j4 install && \
  mv -v /usr/bin/fuser   /bin && \
  mv -v /usr/bin/killall /bin

  rm -Rf "${psmisc}"

}

_iana_etc() {
# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/iana-etc.html

  iana-etc_source=$( find $SRC -name iana-etc*.tar.bz2 )
  iana-etc=${iana-etc_source%.tar.bz2}

  cd "${SRC}" && \
  tar -vxf "${iana-etc_source}"

  cd "${iana-etc}" && \
  make -j4 && \
  make -j4 install

  rm -Rf "${iana-etc}"
}

_bison() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/bison.html

  bison_source=$( find $SRC -name bison*.tar.xz )
  bison=${bison_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${bison_source}"

  cd "${bison}" && \
  sed -i '6855 s/mv/cp/' Makefile.in && \
  ./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.4.1 && \
  make -j1 && \
  make install

  rm -Rf "${bison}"

}

_flex() {

 # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/flex.html

  flex_source=$( find $SRC -name flex*.tar.gz )
  flex=${flex_source%.tar.gz}

  cd "${SRC}" && \
  tar -vxf "${flex_source}"

  cd "${flex}" && \
  sed -i "/math.h/a #include <malloc.h>" src/flexdef.h

  cd "${flex}" && \
  HELP2MAN=/tools/bin/true \
  ./configure --prefix=/usr --docdir=/usr/share/doc/flex-2.6.4

  cd "${flex}" && \
  make -j4 && \
  make -j4 install && \
  ln -sv flex /usr/bin/lex

  rm -Rf "${flex}"

}

_grep() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/grep.html

  grep_source=$( find $SRC -name grep*.tar.xz )
  grep=${grep_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${grep_source}"

  cd "${grep}" && \
  ./configure --prefix=/usr --bindir=/bin && \
  make -j4 && \
  make -j4 install

  rm -Rf "${grep}"

}

_bash() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/bash.html

  bash_source=$( find $SRC -name bash*.tar.gz )
  bash=${bash_source%.tar.gz}

  cd "${SRC}" && \
  tar -vxf "${bash_source}"

  cd "${bash}" && \
  ./configure --prefix=/usr                    \
              --docdir=/usr/share/doc/bash-5.0 \
              --without-bash-malloc            \
              --with-installed-readline

  cd "${bash}" && \
  make -j4 && \
  make -j4 install && \
  mv -vf /usr/bin/bash /bin && \
  exec /bin/bash --login +h

  rm -Rf "${bash}"

}

_libtool() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/libtool.html

  libtool_source=$( find $SRC -name libtool*.tar.xz )
  libtool=${libtool_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${libtool_source}"

  cd "${libtool}" && \
  ./configure --prefix=/usr && \
  make -j4 && \
  make -j4 install

  rm -Rf "${libtool}"

}

_gdbm() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/gdbm.html

  gdbm_source=$( find $SRC -name gdbm*.tar.gz )
  gdbm=${gdbm_source%.tar.gz}

  cd "${SRC}" && \
  tar -vxf "${gdbm_source}"

  cd "${gdbm}" && \
  ./configure --prefix=/usr    \
              --disable-static \
              --enable-libgdbm-compat

  cd "${gdbm}" && \
  make -j4 && \
  make -j4 install

  rm -Rf "${gdbm}"

}

_gperf() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/gperf.html

  gperf_source=$( find $SRC -name gperf*.tar.gz )
  gperf=${gperf_source%.tar.gz}

  cd "${SRC}" && \
  tar -vxf "${gperf_source}"

  cd "${gperf}" && \
  ./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.1 && \
  make -j4 && \
  make -j4 install

  rm -Rf "${gperf}"

}

_expat() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/expat.html

  expat_source=$( find $SRC -name expat*.tar.xz )
  expat=${expat_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${expat_source}"

  cd "${expat}" && \
  sed -i 's|usr/bin/env |bin/|' run.sh.in

  cd "${expat}" && \
  ./configure --prefix=/usr    \
              --disable-static \
              --docdir=/usr/share/doc/expat-2.2.7

  cd "${expat}" && \
  make -j4 && \
  make -j4 install

  rm -Rf "${expat}"

}

_inetutils() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/inetutils.html

  inetutils_source=$( find $SRC -name inetutils*.tar.xz )
  inetutils=${inetutils_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${inetutils_source}"

  cd "${inetutils}" && \
  ./configure --prefix=/usr        \
              --localstatedir=/var \
              --disable-logger     \
              --disable-whois      \
              --disable-rcp        \
              --disable-rexec      \
              --disable-rlogin     \
              --disable-rsh        \
              --disable-servers

  cd "${inetutils}" && \
  make -j4 && \
  make -j4 install && \
  mv -v /usr/bin/{hostname,ping,ping6,traceroute} /bin && \
  mv -v /usr/bin/ifconfig /sbin

  rm -Rf "${inetutils}"

}

_perl() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/perl.html

  perl_source=$( find $SRC -name perl*.tar.xz )
  perl=${perl_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${perl_source}"

  cd "${perl}" && \
  echo "127.0.0.1 localhost $(hostname)" > /etc/hosts

  cd "${perl}" && \
  export BUILD_ZLIB=False
  export BUILD_BZIP2=0

  cd "${perl}" && \
  sh Configure -des -Dprefix=/usr                 \
                    -Dvendorprefix=/usr           \
                    -Dman1dir=/usr/share/man/man1 \
                    -Dman3dir=/usr/share/man/man3 \
                    -Dpager="/usr/bin/less -isR"  \
                    -Duseshrplib                  \
                    -Dusethreads

  cd "${perl}" && \
  make -j4 && \
  make -j4 install && \
  unset BUILD_ZLIB BUILD_BZIP2

  rm -Rf "${perl}"

}

_xml_parser() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/xml-parser.html

  xml_parser_source=$( find $SRC -name XML_Parser*.tar.gz )
  xml_parser=${xml_parser_source%.tar.gz}

  cd "${SRC}" && \
  tar -vxf "${xml_parser_source}"

  cd "${xml_parser}" && \
  perl Makefile.PL && \
  make -j4 && \
  make -j4 install

  rm -Rf "${xml_parser}"

}

_intltool() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/intltool.html

  intltool_source=$( find $SRC -name intltool*.tar.gz )
  intltool=${intltool_source%.tar.gz}

  cd "${SRC}" && \
  tar -vxf "${intltool_source}"

  cd "${intltool}" && \
  sed -i 's:\\\${:\\\$\\{:' intltool-update.in && \
  ./configure --prefix=/usr && \
  make -j4 && \
  make -j4 install && \
  install -v -Dm644 doc/I18N-HOWTO /usr/share/doc/intltool-0.51.0/I18N-HOWTO

  rm -Rf "${intltool}"

}

_autoconf() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/autoconf.html

  autoconf_source=$( find $SRC -name autoconf*.tar.xz )
  autoconf=${autoconf_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${autoconf_source}"

  cd "${autoconf}" && \
  sed '361 s/{/\\{/' -i bin/autoscan.in && \
  ./configure --prefix=/usr && \
  make -j4 && \
  make -j4 install

  rm -Rf "${autoconf}"

}

_automake() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/automake.html

  automake_source=$( find $SRC -name automake*.tar.xz )
  automake=${automake_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${automake_source}"

  cd "${automake}" && \
  ./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.16.1 && \
  make -j4 && \
  make -j4 install

  rm -Rf "${automake}"

}

_xz() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/xz.html

  xz_source=$( find $SRC -name xz*.tar.xz )
  xz=${xz_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${xz_source}"

  cd "${xz}" && \
  ./configure --prefix=/usr    \
              --disable-static \
              --docdir=/usr/share/doc/xz-5.2.4

  cd "${xz}" && \
  make -j4 && \
  make -j4 install && \
  mv -v   /usr/bin/{lzma,unlzma,lzcat,xz,unxz,xzcat} /bin && \
  mv -v /usr/lib/liblzma.so.* /lib && \
  ln -svf ../../lib/$(readlink /usr/lib/liblzma.so) /usr/lib/liblzma.so

  rm -Rf "${xz}"

}

_kmod() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/kmod.html

  kmod_source=$( find $SRC -name kmod*.tar.xz )
  kmod=${kmod_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${kmod_source}"

  cd "${kmod}" && \
  ./configure --prefix=/usr          \
              --bindir=/bin          \
              --sysconfdir=/etc      \
              --with-rootlibdir=/lib \
              --with-xz              \
              --with-zlib

  cd "${kmod}" && \
  make -j4 && \
  make -j4 install

  cd "${kmod}" && \
  for target in depmod insmod lsmod modinfo modprobe rmmod; do
    ln -sfv ../bin/kmod /sbin/$target
  done

  cd "${kmod}" && \
  ln -sfv kmod /bin/lsmod

  rm -Rf "${kmod}"

}

_gettext() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/gettext.html

  gettext_source=$( find $SRC -name gettext*.tar.xz )
  gettext=${gettext_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${gettext_source}"

  cd "${gettext}" && \
  ./configure --prefix=/usr    \
              --disable-static \
              --docdir=/usr/share/doc/gettext-0.20.1

  cd "${gettext}" && \
  make -j4 && \
  make -j4 install && \
  chmod -v 0755 /usr/lib/preloadable_libintl.so

  rm -Rf "${gettext}"

}

_libelf() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/libelf.html

  libelf_source=$( find $SRC -name elfutils*.tar.bz2 )
  libelf=${libelf_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${libelf_source}"

  cd "${libelf}" && \
  ./configure --prefix=/usr && \
  make -j4 && \
  make -j4 libelf install && \
  install -vm644 config/libelf.pc /usr/lib/pkgconfig

  rm -Rf "${libelf}"

}

_libffi() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/libffi.html

  libffi_source=$( find $SRC -name libffi*.tar.gz )
  libffi=${libffi_source%.tar.gz}

  cd "${SRC}" && \
  tar -vxf "${libffi_source}"

  cd "${libffi}" && \
  sed -e '/^includesdir/ s/$(libdir).*$/$(includedir)/' \
      -i include/Makefile.in

  cd "${libffi}" && \
  sed -e '/^includedir/ s/=.*$/=@includedir@/' \
      -e 's/^Cflags: -I${includedir}/Cflags:/' \
      -i libffi.pc.in

  cd "${libffi}" && \
  ./configure --prefix=/usr --disable-static --with-gcc-arch=native && \
  make -j4 && \
  make -j4 install

  rm -Rf "${libffi}"

}

_openssl() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/openssl.html

  openssl_source=$( find $SRC -name openssl*.tar.gz )
  openssl=${openssl_source%.tar.gz}

  cd "${SRC}" && \
  tar -vxf "${openssl_source}"

  cd "${openssl}" && \
  sed -i '/\} data/s/ =.*$/;\n    memset(\&data, 0, sizeof(data));/' \
    crypto/rand/rand_lib.c

  cd "${openssl}" && \
  ./config --prefix=/usr         \
           --openssldir=/etc/ssl \
           --libdir=lib          \
           shared                \
           zlib-dynamic

  cd "${openssl}" && \
  make -j4 && \
  sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile && \
  make MANSUFFIX=ssl install

  rm -Rf "${openssl}"

}

_python() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/Python.html

  python_source=$( find $SRC -name Python*.tar.xz )
  python=${python_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${python_source}"

  cd "${python}" && \
  ./configure --prefix=/usr       \
              --enable-shared     \
              --with-system-expat \
              --with-system-ffi   \
              --with-ensurepip=yes

  cd "${python}" && \
  make -j4 && \
  make -j4 install && \
  chmod -v 755 /usr/lib/libpython3.7m.so && \
  chmod -v 755 /usr/lib/libpython3.so && \
  ln -sfv pip3.7 /usr/bin/pip3

  rm -Rf "${python}"

}
_ninja() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/ninja.html

  ninja_source=$( find $SRC -name ninja*.tar.gz )
  ninja=${ninja_source%.tar.gz}

  cd "${SRC}" && \
  tar -vxf "${ninja_source}"

  export NINJAJOBS=4

  cd "${ninja}" && \
  sed -i '/int Guess/a \
    int   j = 0;\
    char* jobs = getenv( "NINJAJOBS" );\
    if ( jobs != NULL ) j = atoi( jobs );\
    if ( j > 0 ) return j;\
  ' src/ninja.cc

  cd "${ninja}" && \
  python3 configure.py --bootstrap && \
  install -vm755 ninja /usr/bin/ && \
  install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja && \
  install -vDm644 misc/zsh-completion  /usr/share/zsh/site-functions/_ninja

  rm -Rf "${ninja}"

}

_meson() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/meson.html

  meson_source=$( find $SRC -name meson*.tar.gz )
  meson=${meson_source%.tar.gz}

  cd "${SRC}" && \
  tar -vxf "${meson_source}"

  cd "${meson}" && \
  python3 setup.py build && \
  python3 setup.py install --root=dest && \
  cp -rv dest/* /

  rm -Rf "${meson}"

}

_coreutils() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/coreutils.html

  coreutils_source=$( find $SRC -name coreutils*.tar.xz )
  coreutils=${coreutils_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${coreutils_source}"

  cd "${coreutils}" && \
  patch -Np1 -i ../coreutils-8.31-i18n-1.patch && \
  sed -i '/test.lock/s/^/#/' gnulib-tests/gnulib.mk && \
  autoreconf -fiv

  cd "${coreutils}" && \
  FORCE_UNSAFE_CONFIGURE=1 ./configure \
              --prefix=/usr            \
              --enable-no-install-program=kill,uptime

  cd "${coreutils}" && \
  make -j4 && \
  make -j4 install && \
  mv -v /usr/bin/{cat,chgrp,chmod,chown,cp,date,dd,df,echo} /bin
  mv -v /usr/bin/{false,ln,ls,mkdir,mknod,mv,pwd,rm} /bin
  mv -v /usr/bin/{rmdir,stty,sync,true,uname} /bin
  mv -v /usr/bin/chroot /usr/sbin
  mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
  sed -i s/\"1\"/\"8\"/1 /usr/share/man/man8/chroot.8
  mv -v /usr/bin/{head,nice,sleep,touch} /bin

  rm -Rf "${coreutils}"

}

_check() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/check.html

  check_source=$( find $SRC -name check*.tar.gz )
  check=${check_source%.tar.gz}

  cd "${SRC}" && \
  tar -vxf "${check_source}"

  cd "${check}" && \
  ./configure --prefix=/usr && \
  make -j4 && \
  make -j4 docdir=/usr/share/doc/check-0.12.0 install && \
  sed -i '1 s/tools/usr/' /usr/bin/checkmk

  rm -Rf "${check}"

}

_diffutils() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/diffutils.html

  diffutils_source=$( find $SRC -name diffutils*.tar.xz )
  diffutils=${diffutils_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${diffutils_source}"

  cd "${diffutils}" && \
  ./configure --prefix=/usr && \
  make -j4 && \
  make -j4 install

  rm -Rf "${diffutils}"

}

_gawk() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/gawk.html

  gawk_source=$( find $SRC -name gawk*.tar.xz )
  gawk=${gawk_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${gawk_source}"

  cd "${gawk}" && \
  sed -i 's/extras//' Makefile.in && \
  ./configure --prefix=/usr && \
  make -j4 && \
  make -j4 install

  rm -Rf "${gawk}"

}

_findutils() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/findutils.html

  findutils_source=$( find $SRC -name findutils*.tar.gz )
  findutils=${findutils_source%.tar.gz}

  cd "${SRC}" && \
  tar -vxf "${findutils_source}"

  cd "${findutils}" && \
  sed -i 's/test-lock..EXEEXT.//' tests/Makefile.in && \
  sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' gl/lib/*.c && \
  sed -i '/unistd/a #include <sys/sysmacros.h>' gl/lib/mountlist.c && \
  echo "#define _IO_IN_BACKUP 0x100" >> gl/lib/stdio-impl.h

  cd "${findutils}" && \
  ./configure --prefix=/usr --localstatedir=/var/lib/locate && \
  make -j4 && \
  make -j4 install && \
  mv -v /usr/bin/find /bin && \
  sed -i 's|find:=${BINDIR}|find:=/bin|' /usr/bin/updatedb

  rm -Rf "${findutils}"

}

_groff() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/groff.html

  groff_source=$( find $SRC -name groff*.tar.gz )
  groff=${groff_source%.tar.gz}

  cd "${SRC}" && \
  tar -vxf "${groff_source}"

  cd "${groff}" && \
  PAGE=letter ./configure --prefix=/usr && \
  make -j1 && \
  make install

  rm -Rf "${groff}"

}

_grub() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/grub.html

  grub_source=$( find $SRC -name grub*.tar.gz )
  grub=${grub_source%.tar.gz}

  cd "${SRC}" && \
  tar -vxf "${grub_source}"

  cd "${grub}" && \
  ./configure --prefix=/usr          \
              --sbindir=/sbin        \
              --sysconfdir=/etc      \
              --disable-efiemu       \
              --disable-werror

  cd "${grub}" && \
  make -j4 && \
  make -j4 install && \
  mv -v /etc/bash_completion.d/grub /usr/share/bash-completion/completions

  rm -Rf "${grub}"

}

_less() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/less.html

  less_source=$( find $SRC -name less*.tar.gz )
  less=${less_source%.tar.gz}

  cd "${SRC}" && \
  tar -vxf "${less_source}"

  cd "${less}" && \
  ./configure --prefix=/usr --sysconfdir=/etc && \
  make -j4 && \
  make -j4 install

  rm -Rf "${less}"

}

_gzip() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/gzip.html

  gzip_source=$( find $SRC -name gzip*.tar.xz )
  gzip=${gzip_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${gzip_source}"

  cd "${gzip}" && \
  ./configure --prefix=/usr && \
  make -j4 && \
  make -j4 install && \
  mv -v /usr/bin/gzip /bin

  rm -Rf "${gzip}"

}

_iproute() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/iproute2.html

  iproute_source=$( find $SRC -name iproute*.tar.xz )
  iproute=${iproute_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${iproute_source}"

  cd "${iproute}" && \
  sed -i /ARPD/d Makefile && \
  rm -fv man/man8/arpd.8 && \
  sed -i 's/.m_ipt.o//' tc/Makefile && \
  make -j4 && \
  make -j4 DOCDIR=/usr/share/doc/iproute2-5.2.0 install

  rm -Rf "${iproute}"

}

_kbd() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/kbd.html

  kbd_source=$( find $SRC -name kbd*.tar.xz )
  kbd=${kbd_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${kbd_source}"

  cd "${kbd}" && \
  patch -Np1 -i ../kbd-2.2.0-backspace-1.patch && \
  sed -i 's/\(RESIZECONS_PROGS=\)yes/\1no/g' configure && \
  sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in

  cd "${kbd}" && \
  PKG_CONFIG_PATH=/tools/lib/pkgconfig ./configure --prefix=/usr --disable-vlock

  cd "${kbd}" && \
  make -j4 && \
  make -j4 install

  rm -Rf "${kbd}"

}

_libpipeline() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/libpipeline.html

  libpipeline_source=$( find $SRC -name libpipeline*.tar.gz )
  libpipeline=${libpipeline_source%.tar.gz}

  cd "${SRC}" && \
  tar -vxf "${libpipeline_source}"

  cd "${libpipeline}" && \
  ./configure --prefix=/usr && \
  make -j4 && \
  make -j4 install

  rm -Rf "${libpipeline}"

}

_make() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/make.html

  make_source=$( find $SRC -name make*.tar.gz )
  make=${make_source%.tar.gz}

  cd "${SRC}" && \
  tar -vxf "${make_source}"

  cd "${make}" && \
  sed -i '211,217 d; 219,229 d; 232 d' glob/glob.c && \
  make -j4 && \
  make -j4 install

  rm -Rf "${make}"

}

_patch() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/patch.html

  patch_source=$( find $SRC -name patch*.tar.xz )
  patch=${patch_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${patch_source}"

  cd "${patch}" && \
  ./configure --prefix=/usr && \
  make -j4 && \
  make -j4 install

  rm -Rf "${patch}"

}

_mandb() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/man-db.html

  mandb_source=$( find $SRC -name man-db*.tar.xz )
  mandb=${mandb_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${mandb_source}"

  cd "${mandb}" && \
  ./configure --prefix=/usr                        \
            --docdir=/usr/share/doc/man-db-2.8.6.1 \
              --sysconfdir=/etc                    \
              --disable-setuid                     \
              --enable-cache-owner=bin             \
              --with-browser=/usr/bin/lynx         \
              --with-vgrind=/usr/bin/vgrind        \
              --with-grap=/usr/bin/grap            \
              --with-systemdtmpfilesdir=           \
              --with-systemdsystemunitdir=

  cd "${mandb}" && \
  make -j4 && \
  make -j4 install

  rm -Rf "${mandb}"

}

_tar() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/tar.html

  _tar_source=$( find $SRC -name tar*.tar.xz )
  _tar=${_tar_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${_tar_source}"

  cd "${_tar}" && \
  FORCE_UNSAFE_CONFIGURE=1  \
  ./configure --prefix=/usr \
              --bindir=/bin

  cd "${_tar}" && \
  make -j4 && \
  make -j4 install && \
  make -j4 -C doc install-html docdir=/usr/share/doc/tar-1.32

  rm -Rf "${_tar}"

}

_texinfo() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/texinfo.html

  texinfo_source=$( find $SRC -name texinfo*.tar.xz )
  texinfo=${texinfo_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${texinfo_source}"

  cd "${texinfo}" && \
  ./configure --prefix=/usr --disable-static && \
  make -j4 && \
  make -j4 install

  rm -Rf "${texinfo}"

}

_vim() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/vim.html

  vim_source=$( find $SRC -name vim*.tar.gz )
  vim=${vim_source%.tar.gz}

  cd "${SRC}" && \
  tar -vxf "${vim_source}"

  cd "${vim}" && \
  echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h && \
  ./configure --prefix=/usr && \
  make -j4 && \
  make -j4 install

  cd "${vim}" && \
  ln -sv vim /usr/bin/vi && \
  for L in  /usr/share/man/{,*/}man1/vim.1; do
      ln -sv vim.1 $(dirname $L)/vi.1
  done

  cd "${vim}" && \
  ln -sv ../vim/vim81/doc /usr/share/doc/vim-8.1.1846

cat > /etc/vimrc << "EOF"
" Begin /etc/vimrc

" Ensure defaults are set before customizing settings, not after
source $VIMRUNTIME/defaults.vim
let skip_defaults_vim=1 

set nocompatible
set backspace=2
set mouse=
syntax on
if (&term == "xterm") || (&term == "putty")
  set background=dark
endif

" End /etc/vimrc
EOF

  rm -Rf "${vim}"

}

_procps_ng() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/procps-ng.html

  procps-ng_source=$( find $SRC -name procps-ng*.tar.xz )
  procps-ng=${procps-ng_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${procps-ng_source}"

  cd "${procps-ng}" && \
  ./configure --prefix=/usr                            \
              --exec-prefix=                           \
              --libdir=/usr/lib                        \
              --docdir=/usr/share/doc/procps-ng-3.3.15 \
              --disable-static                         \
              --disable-kill

  cd "${procps-ng}" && \
  make -j4 && \
  make -j4 install && \
  mv -v /usr/lib/libprocps.so.* /lib && \
  ln -sfv ../../lib/$(readlink /usr/lib/libprocps.so) /usr/lib/libprocps.so

  rm -Rf "${procps-ng}"

}

_util_linux() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/util-linux.html

  util-linux_source=$( find $SRC -name util-linux*.tar.xz )
  util-linux=${util-linux_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${util-linux_source}"

  cd "${util-linux}" && \
  mkdir -pv /var/lib/hwclock

  cd "${util-linux}" && \
  ./configure ADJTIME_PATH=/var/lib/hwclock/adjtime   \
              --docdir=/usr/share/doc/util-linux-2.34 \
              --disable-chfn-chsh  \
              --disable-login      \
              --disable-nologin    \
              --disable-su         \
              --disable-setpriv    \
              --disable-runuser    \
              --disable-pylibmount \
              --disable-static     \
              --without-python     \
              --without-systemd    \
              --without-systemdsystemunitdir

  cd "${util-linux}" && \
  make -j4 && \
  make -j4 install

  rm -Rf "${util_linux}"

}

_e2fsprogs() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/e2fsprogs.html

  e2fsprogs_source=$( find $SRC -name e2fsprogs*.tar.gz )
  e2fsprogs=${e2fsprogs_source%.tar.gz}
  build="${e2fsprogs}/build"

  cd "${SRC}" && \
  tar -vxf "${e2fsprogs_source}"

  cd "${e2fsprogs}" && \
  mkdir -v build

  cd "${build}" && \
  ../configure --prefix=/usr           \
               --bindir=/bin           \
               --with-root-prefix=""   \
               --enable-elf-shlibs     \
               --disable-libblkid      \
               --disable-libuuid       \
               --disable-uuidd         \
               --disable-fsck

  cd "${build}" && \
  make -j4 && \
  make -j4 install && \
  make -j4 install-libs && \
  chmod -v u+w /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a && \
  gunzip -v /usr/share/info/libext2fs.info.gz && \
  install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info

  rm -Rf "${e2fsprogs}"

}

_sysklogd() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/sysklogd.html

  sysklogd_source=$( find $SRC -name sysklogd*.tar.gz )
  sysklogd=${sysklogd_source%.tar.gz}

  cd "${SRC}" && \
  tar -vxf "${sysklogd_source}"

  cd "${sysklogd}" && \
  sed -i '/Error loading kernel symbols/{n;n;d}' ksym_mod.c && \
  sed -i 's/union wait/int/' syslogd.c && \
  make -j4 && \
  make -j4 BINDIR=/sbin install

cat > /etc/syslog.conf << "EOF"
# Begin /etc/syslog.conf

auth,authpriv.* -/var/log/auth.log
*.*;auth,authpriv.none -/var/log/sys.log
daemon.* -/var/log/daemon.log
kern.* -/var/log/kern.log
mail.* -/var/log/mail.log
user.* -/var/log/user.log
*.emerg *

# End /etc/syslog.conf
EOF

  rm -Rf "${sysklogd}"

}

_sysvinit() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/sysvinit.html

  sysvinit_source=$( find $SRC -name sysvinit*.tar.xz )
  sysvinit=${sysvinit_source%.tar.xz}

  cd "${SRC}" && \
  tar -vxf "${sysvinit_source}"

  cd "${sysvinit}" && \
  patch -Np1 -i ../sysvinit-2.95-consolidated-1.patch && \
  make -j4 && \
  make -j4 install

  rm -Rf "${sysvinit}"

}

_eudev() {

  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/eudev.html

  eudev_source=$( find $SRC -name eudev*.tar.gz )
  eudev=${eudev_source%.tar.gz}

  cd "${SRC}" && \
  tar -vxf "${eudev_source}"

  cd "${eudev}" && \
  ./configure --prefix=/usr           \
              --bindir=/sbin          \
              --sbindir=/sbin         \
              --libdir=/usr/lib       \
              --sysconfdir=/etc       \
              --libexecdir=/lib       \
              --with-rootprefix=      \
              --with-rootlibdir=/lib  \
              --enable-manpages       \
              --disable-static

  cd "${eudev}" && \
  make -j4 && \
  make -j4 install && \
  tar -xvf ../udev-lfs-20171102.tar.xz && \
  make -f udev-lfs-20171102/Makefile.lfs install

  udevadm hwdb --update

  rm -Rf "${eudev}"

}

#_stripping() {
  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/strippingagain.html
  # unnecessary for me
#}

#_cleanup() {
  # http://www.linuxfromscratch.org/lfs/view/stable/chapter06/revisedchroot.html
  # do this manually
#}

_creatingdirs
_createfiles
_linux_headers
_man_pages
_glibc
_adjusting_toolchain
_zlib
_file
_readline
_m4
_bc
_binutils
_gmp
_mpfr
_mpc
_shadow
_gcc
_bzip2
_pkg_config
_ncurses
_attr
_acl
_libcap
_sed
_psmisc
_iana_etc
_bison
_flex
_grep
_bash
_libtool
_gdbm
_gperf
_expat
_inetutils
_perl
_xml_parser
_intltool
_autoconf
_automake
_xz
_kmod
_gettext
_libelf
_libffi
_openssl
_python
_ninja
_meson
_coreutils
_check
_diffutils
_gawk
_finutils
_groff
_grub
_less
_gzip
_iproute
_kbd
_libpipeline
_make
_patch
_mandb
_tar
_texinfo
_vim
_procps_ng
_util_linux
_e2fsprogs
_sysklogd
_sysvinit
_eudev

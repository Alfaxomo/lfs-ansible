#!/bin/bash

SRC=/sources

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
}

_pkg_config() {
}

_ncurses() {
}

_attr() {
}

_acl() {
}

_libcap() {
}

_sed() {
}

_psmisc() {
}

_iana_etc() {
}

_bison() {
}

_flex() {
}

_grep() {
}

_bash() {
}

_libtool() {
}

_gdbm() {
}

_gperf() {
}

_expat() {
}

_inetutils() {
}

_perl() {
}

_xml_parser() {
}

_intltool() {
}

_autoconf() {
}

_automake() {
}

_xz() {
}

_kmod() {
}

_gettext() {
}

_libelf() {
}

_libffi() {
}

_openssl() {

}

_python() {

}
_ninja() {
}

_meson() {
}

_coreutils() {
}

_check() {
}

_diffutils() {
}

_gawk() {
}

_finutils() {
}

_groff() {
}

_grub() {
}

_less() {
}

_gzip() {
}

_iproute() {
}

_kbd() {
}

_libpipeline() {
}

_make() {
}

_patch() {
}

_mandb() {
}

_tar() {
}

_texinfo() {
}

_vim() {
}

_procps_ng() {
}

_util_linux() {
}

_e2fsprogs() {
}

_sysklogd() {
}

_sysvinit() {
}

_eudev() {
}

_stripping() {
}

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
_stripping
_cleaning

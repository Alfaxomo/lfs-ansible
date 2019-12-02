#!/bin/bash

LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$( uname -m )-lfs-linux-gnu
lfs=/mnt/lfs
lfs_src=/mnt/lfs/sources

_binutils_pass1() {

 binutils_source=$( find /mnt/lfs/sources -name binutils*.tar.xz )
 # https://stackoverflow.com/questions/125281/how-do-i-remove-the-file-suffix-and-path-portion-from-a-path-string-in-bash
 binutils=${binutils_source%.tar.xz}
 build="${binutils}/build"

  cd "${lfs_src}" && \
  tar -vxf "${binutils_source}"

  cd "${binutils}" && \
  mkdir build

  cd "${build}" && \
  ../configure               \
  --prefix=/tools            \
  --with-sysroot=$LFS        \
  --with-lib-path=/tools/lib \
  --target=$LFS_TGT          \
  --disable-nls              \
  --disable-werror

  cd "${build}" && \
  make -j4

  cd "${build}" && \
  case $(uname -m) in
    x86_64) mkdir -v /tools/lib && ln -sv lib /tools/lib64 ;;
  esac

  cd "${build}" && \
  make -j4 install

  rm -Rf "${binutils}"

}

_gcc_pass1() {

  gcc_source=$( find /mnt/lfs/sources -name gcc*.tar.xz )
  gcc=${gcc_source%.tar.xz}
  build="${gcc}/build"

  mpfr_source=$( find /mnt/lfs/sources -name mpfr*.tar.xz )
  mpfr_full=$( basename $mpfr_source )
  mpfr_base=$( basename "${mpfr_source%.tar.xz}" )

  gmp_source=$( find /mnt/lfs/sources -name gmp*.tar.xz )
  gmp_full=$( basename $gmp_source )
  gmp_base=$( basename "${gmp_source%.tar.xz}" )

  mpc_source=$( find /mnt/lfs/sources -name mpc*.tar.gz )
  mpc_full=$( basename $mpc_source )
  mpc_base=$( basename "${mpc_source%.tar.gz}" )

  echo "${mpfr_source}"
  echo "${mpfr_full}"
  echo "${mpfr_base}"

  cd "${lfs_src}" && \
  tar -vxf "${gcc_source}"

  cd "${gcc}" && \
  tar -xf ../"${mpfr_full}" && \
  mv -v "${mpfr_base}" mpfr && \
  tar -xf ../"${gmp_full}" && \
  mv -v "${gmp_base}" gmp && \
  tar -xf ../"${mpc_full}" && \
  mv -v "${mpc_base}" mpc

  cd "${gcc}" && \
  for file in gcc/config/{linux,i386/linux{,64}}.h
  do
    cp -uv $file{,.orig}
    sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
        -e 's@/usr@/tools@g' $file.orig > $file
    echo '
  #undef STANDARD_STARTFILE_PREFIX_1
  #undef STANDARD_STARTFILE_PREFIX_2
  #define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
  #define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
    touch $file.orig
  done

  cd "${gcc}" && \
  case $(uname -m) in
    x86_64)
      sed -e '/m64=/s/lib64/lib/' \
          -i.orig gcc/config/i386/t-linux64
   ;;
  esac

  cd "${gcc}" && \
  mkdir build

  cd "${build}" && \
  ../configure                                       \
    --target=$LFS_TGT                              \
    --prefix=/tools                                \
    --with-glibc-version=2.11                      \
    --with-sysroot=$LFS                            \
    --with-newlib                                  \
    --without-headers                              \
    --with-local-prefix=/tools                     \
    --with-native-system-header-dir=/tools/include \
    --disable-nls                                  \
    --disable-shared                               \
    --disable-multilib                             \
    --disable-decimal-float                        \
    --disable-threads                              \
    --disable-libatomic                            \
    --disable-libgomp                              \
    --disable-libquadmath                          \
    --disable-libssp                               \
    --disable-libvtv                               \
    --disable-libstdcxx                            \
    --enable-languages=c,c++

  cd "${build}" && \
  make -j4 && \
  make -j4 install

  rm -Rf "${gcc}"

}

_linux_headers() {

  linux_source=$( find /mnt/lfs/sources -name linux*.tar.xz )
  linux=${linux_source%.tar.xz}
  build="${linux}/build"

  cd "${lfs_src}" && \
  tar -vxf "${linux_source}"

  cd "${linux}" && \
  make mrproper

  cd "${linux}" && \
  make INSTALL_HDR_PATH=dest headers_install

  cd "${linux}" && \
  cp -rv dest/include/* /tools/include

  rm -Rf "${linux}"

}

_glibc() {

  glibc_source=$( find /mnt/lfs/sources -name glibc*.tar.xz )
  glibc=${glibc_source%.tar.xz}
  build="${glibc}/build"

  cd "${lfs_src}" && \
  tar -vxf "${glibc_source}"

  cd "${glibc}" && \
  mkdir build

  cd "${build}" && \
  ../configure                             \
        --prefix=/tools                    \
        --host=$LFS_TGT                    \
        --build=$(../scripts/config.guess) \
        --enable-kernel=3.2                \
        --with-headers=/tools/include

  cd "${build}" && \
  make -j4 && \
  make -j4 install

  cd "${build}" && \
  echo 'int main(){}' > dummy.c
  $LFS_TGT-gcc dummy.c
  readelf -l a.out | grep ': /tools'

  #readelf_check=$( readelf -l a.out | grep ': /tools' )
  # if [[ "${readelf_check}" does not contain "/tools/lib64/ld-linux-x86-64.so.2"; then
  #   echo "check failed"
  # else
  #   echo "check passed"
  # fi

  rm -v dummy.c a.out
  rm -Rf "${glibc}"

}

_libstdc() {

  gcc_source=$( find /mnt/lfs/sources -name gcc*.tar.xz )
  gcc=${gcc_source%.tar.xz}
  build="${gcc}/build"

  cd "${lfs_src}" && \
  tar -vxf "${gcc_source}"

  cd "${gcc}" && \
  mkdir build

  cd "${build}" && \
  ../libstdc++-v3/configure           \
      --host=$LFS_TGT                 \
      --prefix=/tools                 \
      --disable-multilib              \
      --disable-nls                   \
      --disable-libstdcxx-threads     \
      --disable-libstdcxx-pch         \
      --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/9.2.0

  cd "${build}" && \
  make -j4 && \
  make -j4 install

  rm -Rf "${gcc}"

}

_binutils_pass2() {

 binutils_source=$( find /mnt/lfs/sources -name binutils*.tar.xz )
 binutils=${binutils_source%.tar.xz}
 build="${binutils}/build"

  cd "${lfs_src}" && \
  tar -vxf "${binutils_source}"

  cd "${binutils}" && \
  mkdir build

  cd "${build}" && \
  CC=$LFS_TGT-gcc                \
  AR=$LFS_TGT-ar                 \
  RANLIB=$LFS_TGT-ranlib         \
  ../configure                   \
      --prefix=/tools            \
      --disable-nls              \
      --disable-werror           \
      --with-lib-path=/tools/lib \
      --with-sysroot

  cd "${build}" && \
  make -j4 && \
  make -j4 install

  cd "${build}" && \
  make -C ld clean && \
  make -C ld LIB_PATH=/usr/lib:/lib && \
  cp -v ld/ld-new /tools/bin

  rm -Rf "${binutils}"

}

_gcc_pass2() {

  gcc_source=$( find /mnt/lfs/sources -name gcc*.tar.xz )
  gcc=${gcc_source%.tar.xz}
  build="${gcc}/build"

  mpfr_source=$( find /mnt/lfs/sources -name mpfr*.tar.xz )
  mpfr_full=$( basename $mpfr_source )
  mpfr_base=$( basename "${mpfr_source%.tar.xz}" )

  gmp_source=$( find /mnt/lfs/sources -name gmp*.tar.xz )
  gmp_full=$( basename $gmp_source )
  gmp_base=$( basename "${gmp_source%.tar.xz}" )

  mpc_source=$( find /mnt/lfs/sources -name mpc*.tar.gz )
  mpc_full=$( basename $mpc_source )
  mpc_base=$( basename "${mpc_source%.tar.gz}" )

  cd "${lfs_src}" && \
  tar -vxf "${gcc_source}"

  cd "${gcc}" && \
  cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
    `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include-fixed/limits.h

  cd "${gcc}" && \
  for file in gcc/config/{linux,i386/linux{,64}}.h
  do
    cp -uv $file{,.orig}
    sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
        -e 's@/usr@/tools@g' $file.orig > $file
    echo '
  #undef STANDARD_STARTFILE_PREFIX_1
  #undef STANDARD_STARTFILE_PREFIX_2
  #define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
  #define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
    touch $file.orig
  done

  cd "${gcc}" && \
  case $(uname -m) in
    x86_64)
      sed -e '/m64=/s/lib64/lib/' \
          -i.orig gcc/config/i386/t-linux64
    ;;
  esac

  cd "${gcc}" && \
  tar -xf ../"${mpfr_full}" && \
  mv -v "${mpfr_base}" mpfr && \
  tar -xf ../"${gmp_full}" && \
  mv -v "${gmp_base}" gmp && \
  tar -xf ../"${mpc_full}" && \
  mv -v "${mpc_base}" mpc

  cd "${gcc}" && \
  mkdir build

  cd "${build}" && \
  CC=$LFS_TGT-gcc                                    \
  CXX=$LFS_TGT-g++                                   \
  AR=$LFS_TGT-ar                                     \
  RANLIB=$LFS_TGT-ranlib                             \
  ../configure                                       \
      --prefix=/tools                                \
      --with-local-prefix=/tools                     \
      --with-native-system-header-dir=/tools/include \
      --enable-languages=c,c++                       \
      --disable-libstdcxx-pch                        \
      --disable-multilib                             \
      --disable-bootstrap                            \
      --disable-libgomp

  cd "${build}" && \
  make -j4 && \
  make -j4 install

  cd "${build}" && \
  ln -sv gcc /tools/bin/cc

  cd "${build}" && \
  echo 'int main(){}' > dummy.c
  cc dummy.c
  readelf -l a.out | grep ': /tools'

  #readelf_check=$( readelf -l a.out | grep ': /tools' )
  # if [[ "${readelf_check}" does not contain "/tools/lib64/ld-linux-x86-64.so.2"; then
  #   echo "check failed"
  # else
  #   echo "check passed"
  # fi

  rm -v dummy.c a.out
  rm -Rf "${gcc}"

}

_tcl() {

  tcl_source=$( find /mnt/lfs/sources -name tcl*.tar.gz )
  tcl=${tcl_source%-src.tar.gz}
  build="${tcl}/unix"

  cd "${lfs_src}" && \
  tar -vxf "${tcl_source}"

  cd "${build}" && \
  ./configure --prefix=/tools

  cd "${build}" && \
  make -j4 && \
  make -j4 install && \
  chmod -v u+w /tools/lib/libtcl8.6.so && \
  make install-private-headers && \
  ln -sv tclsh8.6 /tools/bin/tclsh

  rm -Rf "${tcl}"

}

_expect() {

  expect_source=$( find /mnt/lfs/sources -name expect*.tar.gz )
  expect=${expect_source%.tar.gz}
  build="${expect}/build"

  cd "${lfs_src}" && \
  tar -vxf "${expect_source}"

  cd "${expect}" && \
  cp -v configure{,.orig} && \
  sed 's:/usr/local/bin:/bin:' configure.orig > configure

  cd "${expect}" && \
  ./configure --prefix=/tools       \
              --with-tcl=/tools/lib \
              --with-tclinclude=/tools/include

  cd "${expect}" && \
  make -j4 && \
  make -j4 SCRIPTS="" install

  rm -Rf "${expect}"

}

_dejagnu() {

  dejagnu_source=$( find /mnt/lfs/sources -name dejagnu*.tar.gz )
  dejagnu=${dejagnu_source%.tar.gz}
  build="${dejagnu}/build"

  cd "${lfs_src}" && \
  tar -vxf "${dejagnu_source}"

  cd "${dejagnu}" && \
  ./configure --prefix=/tools

  cd "${dejagnu}" && \
  make install

  rm -Rf "${dejagnu}"

}

_m4() {

  m4_source=$( find /mnt/lfs/sources -name m4*.tar.xz )
  m4=${m4_source%.tar.xz}
  build="${m4}/build"

  cd "${lfs_src}" && \
  tar -vxf "${m4_source}"

  cd "${m4}" && \
  sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' lib/*.c && \
  echo "#define _IO_IN_BACKUP 0x100" >> lib/stdio-impl.h

  cd "${m4}" && \
  ./configure --prefix=/tools

  cd "${m4}" && \
  make -j4 && \
  make -j4 install

  rm -Rf "${m4}"

}

_ncurses() {

  ncurses_source=$( find /mnt/lfs/sources -name ncurses*.tar.gz )
  ncurses=${ncurses_source%.tar.gz}

  cd "${lfs_src}" && \
  tar -vxf "${ncurses_source}"

  cd "${ncurses}" && \
  sed -i s/mawk// configure

  cd "${ncurses}" && \
  ./configure --prefix=/tools \
              --with-shared   \
              --without-debug \
              --without-ada   \
              --enable-widec  \
              --enable-overwrite

  cd "${ncurses}" && \
  make -j4 && \
  make -j4 install && \
  ln -s libncursesw.so /tools/lib/libncurses.so

  rm -Rf "${ncurses}"

}

_bash() {

  bash_source=$( find /mnt/lfs/sources -name bash*.tar.gz )
  bash=${bash_source%.tar.gz}

  cd "${lfs_src}" && \
  tar -vxf "${bash_source}"

  cd "${bash}" && \
  ./configure --prefix=/tools --without-bash-malloc

  cd "${bash}" && \
  make -j4 && \
  make -j4 install && \
  ln -sv bash /tools/bin/sh

  rm -Rf "${bash}"

}

_bison() {

  bison_source=$( find /mnt/lfs/sources -name bison*.tar.xz )
  bison=${bison_source%.tar.xz}

  cd "${lfs_src}" && \
  tar -vxf "${bison_source}"

  cd "${bison}" && \
  ./configure --prefix=/tools

  cd "${bison}" && \
  make -j4 && \
  make -j4 install

  rm -Rf "${bison}"

}

_bzip2() {

  bzip2_source=$( find /mnt/lfs/sources -name bzip2*.tar.gz )
  bzip2=${bzip2_source%.tar.gz}

  cd "${lfs_src}" && \
  tar -vxf "${bzip2_source}"

  cd "${bzip2}" && \
  make -j4 && \
  make -j4 PREFIX=/tools install

  rm -Rf "${bzip2}"

}

_coreutils() {

  coreutils_source=$( find /mnt/lfs/sources -name coreutils*.tar.xz )
  coreutils=${coreutils_source%.tar.xz}

  cd "${lfs_src}" && \
  tar -vxf "${coreutils_source}"

  cd "${coreutils}" && \
  ./configure --prefix=/tools --enable-install-program=hostname && \
  make -j4 && \
  make -j4 install

  rm -Rf "${coreutils}"

}

_diffutils() {

  diffutils_source=$( find /mnt/lfs/sources -name diffutils*.tar.xz )
  diffutils=${diffutils_source%.tar.xz}

  cd "${lfs_src}" && \
  tar -vxf "${diffutils_source}"

  cd "${diffutils}" && \
  ./configure --prefix=/tools && \
  make -j4 && \
  make -j4 install

  rm -Rf "${diffutils}"
}

_file() {

  file_source=$( find /mnt/lfs/sources -name file*.tar.gz )
  file=${file_source%.tar.gz}

  cd "${lfs_src}" && \
  tar -vxf "${file_source}"

  cd "${file}" && \
  ./configure --prefix=/tools && \
  make -j4 && \
  make -j4 install

  rm -Rf "${file}"

}

_findutils() {

  findutils_source=$( find /mnt/lfs/sources -name findutils*.tar.gz )
  findutils=${findutils_source%.tar.gz}

  cd "${lfs_src}" && \
  tar -vxf "${findutils_source}"

  cd "${findutils}" && \
  sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' gl/lib/*.c && \
  sed -i '/unistd/a #include <sys/sysmacros.h>' gl/lib/mountlist.c && \
  echo "#define _IO_IN_BACKUP 0x100" >> gl/lib/stdio-impl.h

  cd "${findutils}" && \
  ./configure --prefix=/tools && \
  make -j4 && \
  make -j4 install

  rm -Rf "${findutils}"

}

_gawk() {

  gawk_source=$( find /mnt/lfs/sources -name gawk*.tar.xz )
  gawk=${gawk_source%.tar.xz}

  cd "${lfs_src}" && \
  tar -vxf "${gawk_source}"

  cd "${gawk}" && \
  ./configure --prefix=/tools && \
  make -j4 && \
  make -j4 install

  rm -Rf "${gawk}"

}

_gettext() {

  gettext_source=$( find /mnt/lfs/sources -name gettext*.tar.xz )
  gettext=${gettext_source%.tar.xz}

  cd "${lfs_src}" && \
  tar -vxf "${gettext_source}"

  cd "${gettext}" && \
  ./configure --disable-shared && \
  make -j4 && \
  cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /tools/bin

  rm -Rf "${gettext}"

}

_grep() {

  grep_source=$( find /mnt/lfs/sources -name grep*.tar.xz )
  grep=${grep_source%.tar.xz}

  cd "${lfs_src}" && \
  tar -vxf "${grep_source}"

  cd "${grep}" && \
  ./configure --prefix=/tools && \
  make -j4 && \
  make -j4 install

  rm -Rf "${grep}"

}

_gzip() {

  gzip_source=$( find /mnt/lfs/sources -name gzip*.tar.xz )
  gzip=${gzip_source%.tar.xz}

  cd "${lfs_src}" && \
  tar -vxf "${gzip_source}"

  cd "${gzip}" && \
  ./configure --prefix=/tools && \
  make -j4 && \
  make -j4 install

  rm -Rf "${gzip}"

}

_make() {

  make_source=$( find /mnt/lfs/sources -name make*.tar.gz )
  make=${make_source%.tar.gz}

  cd "${lfs_src}" && \
  tar -vxf "${make_source}"

  cd "${make}" && \
  sed -i '211,217 d; 219,229 d; 232 d' glob/glob.c && \
  ./configure --prefix=/tools --without-guile && \
  make -j4 && \
  make -j4 install

  rm -Rf "${make}"

}

_patch() {

  patch_source=$( find /mnt/lfs/sources -name patch*.tar.xz )
  patch=${patch_source%.tar.xz}

  cd "${lfs_src}" && \
  tar -vxf "${patch_source}"

  cd "${patch}" && \
  ./configure --prefix=/tools && \
  make -j4 && \
  make -j4 install

  rm -Rf "${patch}"

}

_perl() {

  perl_source=$( find /mnt/lfs/sources -name perl*.tar.xz )
  perl=${perl_source%.tar.xz}

  cd "${lfs_src}" && \
  tar -vxf "${perl_source}"

  cd "${perl}" && \
  sh Configure -des -Dprefix=/tools -Dlibs=-lm -Uloclibpth -Ulocincpth

  cd "${perl}" && \
  make -j4 && \
  cp -v perl cpan/podlators/scripts/pod2man /tools/bin && \
  mkdir -pv /tools/lib/perl5/5.30.0 && \
  cp -Rv lib/* /tools/lib/perl5/5.30.0

  rm -Rf "${perl}"

}

_python() {

  python_source=$( find /mnt/lfs/sources -name Python*.tar.xz )
  python=${python_source%.tar.xz}

  cd "${lfs_src}" && \
  tar -vxf "${python_source}"

  cd "${python}" && \
  sed -i '/def add_multiarch_paths/a \        return' setup.py

  cd "${python}" && \
  ./configure --prefix=/tools --without-ensurepip && \
  make -j4 && \
  make -j4 install

  rm -Rf "${python}"

}

_sed() {

  sed_source=$( find /mnt/lfs/sources -name sed*.tar.xz )
  sed=${sed_source%.tar.xz}

  cd "${lfs_src}" && \
  tar -vxf "${sed_source}"

  cd "${sed}" && \
  ./configure --prefix=/tools && \
  make -j4 && \
  make -j4 install

  rm -Rf "${sed}"

}

_tar() {

  _tar_source=$( find /mnt/lfs/sources -name tar*.tar.xz )
  _tar=${_tar_source%.tar.xz}

  cd "${lfs_src}" && \
  tar -vxf "${_tar_source}"

  cd "${_tar}" && \
  ./configure --prefix=/tools && \
  make -j4 && \
  make -j4 install

  rm -Rf "${_tar}"

}

_texinfo() {

  texinfo_source=$( find /mnt/lfs/sources -name texinfo*.tar.xz )
  texinfo=${texinfo_source%.tar.xz}

  cd "${lfs_src}" && \
  tar -vxf "${texinfo_source}"

  cd "${texinfo}" && \
  ./configure --prefix=/tools && \
  make -j4 && \
  make -j4 install

  rm -Rf "${texinfo}" 

}

_xz() {

  _xz_source=$( find /mnt/lfs/sources -name xz*.tar.xz )
  _xz=${_xz_source%.tar.xz}

  cd "${lfs_src}" && \
  tar -vxf "${_xz_source}"

  cd "${_xz}" && \
  ./configure --prefix=/tools && \
  make -j4 && \
  make -j4 install

  rm -Rf "${_xz}"

}

_binutils_pass1
_gcc_pass1
_linux_headers
_glibc
_libstdc
_binutils_pass2
_gcc_pass2
_tcl
_expect
_dejagnu
_m4
_ncurses
_bash
_bison
_bzip2
_coreutils
_diffutils
_file
_findutils
_gawk
_gettext
_grep
_gzip
_make
_patch
_perl
_python
_sed
_tar
_texinfo
_xz

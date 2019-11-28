This role only offers the ability to install the latest and greatest LFS.

TODO List:

- download all packages and make it idempotent
- put packages + versions into variables
-- requires stripping the .tar.gz,bz,xz file extension


Here are the required package versions that I have that worked as per http://www.linuxfromscratch.org/lfs/view/stable/chapter02/hostreqs.html:

bash, version 4.4.23(1)-release
/bin/sh -> /usr/bin/bash
Binutils: version 2.29.1-23.fc28
bison (GNU Bison) 3.0.4
/usr/bin/yacc -> /usr/bin/bison
bzip2,  Version 1.0.6, 6-Sept-2010.
Coreutils:  8.29
diff (GNU diffutils) 3.6
find (GNU findutils) 4.6.0
GNU Awk 4.2.1, API: 2.0 (GNU MPFR 3.1.6-p2, GNU MP 6.1.2)
/usr/bin/awk -> /usr/bin/gawk
gcc (GCC) 8.2.1 20181215 (Red Hat 8.2.1-6)
g++ (GCC) 8.2.1 20181215 (Red Hat 8.2.1-6)
(GNU libc) 2.27
grep (GNU grep) 3.1
gzip 1.9
Linux version 4.19.16-200.fc28.x86_64 (mockbuild@bkernel04.phx2.fedoraproject.org) (gcc version 8.2.1 20181215 (Red Hat 8.2.1-6) (GCC)) #1 SMP Thu Jan 17 00:16:20 UTC 2019
m4 (GNU M4) 1.4.18
GNU Make 4.2.1
GNU patch 2.7.6
Perl version='5.26.3';
Python 3.6.8
sed (GNU sed) 4.5
tar (GNU tar) 1.30
texi2any (GNU texinfo) 6.5
xz (XZ Utils) 5.2.4
g++ compilation OK

-----NOTES-----

blkid | grep sdh1 | awk '{ print $2 }'
UUID="99cbc811-e558-4d7e-b3de-1da0d0f97fca"

blkid | grep sdh2 | awk '{ print $2 }'
UUID="a9dec6bc-61b2-4673-a876-9cca94727e0c"

http://www.linuxfromscratch.org/lfs/view/stable/chapter02/mounting.html

I think my boot problem from the first time stems from missing this part of the documentation

"If using multiple partitions for LFS (e.g., one for / and another for /usr), mount them using:

mkdir -pv $LFS
mount -v -t ext4 /dev/<xxx> $LFS
mkdir -v $LFS/usr
mount -v -t ext4 /dev/<yyy> $LFS/usr"

I should have done:

mkdir -pv $LFS/boot
mount -v -t ext4 /dev/sdh1 $LFS/boot

***REMEMBER TO UNMOUNT SWAP AT THE END***


-----TROUBLESHOOTING-----

mount -v -t ext4 /dev/sdh1 $LFS
mount: /mnt/lfs does not contain SELinux labels.
       You just mounted an file system that supports labels which does not
       contain labels, onto an SELinux box. It is likely that confined
       applications will generate AVC messages and not be allowed access to
       this file system.  For more details see restorecon(8) and mount(8).
mount: /dev/sdh1 mounted on /mnt/lfs.

restorecon /mnt/lfs/

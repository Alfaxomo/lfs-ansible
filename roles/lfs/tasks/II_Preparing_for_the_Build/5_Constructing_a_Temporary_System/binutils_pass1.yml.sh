---

- name: "{{ ansible_distribution }}: Chapter 5.4 binutils pass 1"
  vars:
    msg: |
      Linux From Scratch - Latest Stable
      Chapter 5.4. binutils pass 1
      http://www.linuxfromscratch.org/lfs/view/stable/chapter05/binutils-pass1.html
  debug:
    msg: "{{ msg.split('\n') }}"

- name: "{{ ansible_distribution }}: install binutils_pass1.sh"
  copy:
    dest: /tmp/binutils_pass1.sh
    src: binutils_pass1.sh

- name: "{{ ansible_distribution }}: run binutils.sh"
  become: true
  become_user: lfs
  #shell: source /home/lfs/.bash_profile && bash /tmp/binutils_pass1.sh
  script: /tmp/binutils_pass1.sh

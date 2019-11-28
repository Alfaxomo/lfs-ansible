* ansible-playbook -b --extra-vars="target=localhost" ~/lfs-ansible/lfs-ansible.yml

## Current Issues:
### needs to be run on localhost for lookups to work
### needs to use the ext4 filesystem until i figure out how to compile xfs support properly
### needs to have the disk formatted with ext4 manually as either there is a bug with ansible filesystem module when using ext4 or i'm not using it properly but it doesn't work using ansible

## Future developments:
### add the kickstart that i used to setup the host system

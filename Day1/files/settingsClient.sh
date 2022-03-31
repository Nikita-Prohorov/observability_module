#!/bin/bash
sudo yum -y install openldap-clients nss-pam-ldapd
sudo -i
authconfig --enableldap --enableldapauth --ldapserver=192.168.120.3 --ldapbasedn="dc=devopsldab,dc=com" --enablemkhomedir --update
sudo systemctl restart nslcd

#!/bin/bash
echo "Start Configure"
sudo yum -y install openldap compat-openldap openldap-clients openldap-servers openldap-servers-sql openldap-devel
sudo systemctl start slapd
sudo systemctl enable slapd

echo "Generate Admin Password"
sudo slappasswd -s pass_admin > /tools/filepassroot
echo "Copy ldaprootpasswd.ldif"
cat > /tools/ldaprootpasswd.ldif <<EOF
dn: olcDatabase={0}config,cn=config
changetype: modify
add: olcRootPW
olcRootPW: $(cat /tools/filepassroot)
EOF
sudo ldapmodify -Y EXTERNAL -H ldapi:/// -f /tools/ldaprootpasswd.ldif

echo "Configure LDAP Database "
sudo cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
sudo chown -R ldap:ldap /var/lib/ldap
sudo systemctl restart slapd
sudo ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif
sudo ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif
sudo ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif

cat > /tools/ldapdomain.ldif <<EOF
dn: olcDatabase={1}monitor,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to * by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" read by dn.base="cn=Manager,dc=devopsldab,dc=com" read by * none

dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcSuffix
olcSuffix: dc=devopsldab,dc=com

dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcRootDN
olcRootDN: cn=Manager,dc=devopsldab,dc=com

dn: olcDatabase={2}hdb,cn=config
changetype: modify
add: olcRootPW
olcRootPW: $(cat /tools/filepassroot)

dn: olcDatabase={2}hdb,cn=config
changetype: modify
add: olcAccess
olcAccess: {0}to attrs=userPassword,shadowLastChange by
  dn="cn=Manager,dc=devopsldab,dc=com" write by anonymous auth by self write by * none
olcAccess: {1}to dn.base="" by * read
olcAccess: {2}to * by dn="cn=Manager,dc=devopsldab,dc=com" write by * read
EOF
sudo ldapadd -Y EXTERNAL -H ldapi:/// -f /tools/ldapdomain.ldif

echo "Copy baseldapdomain.ldif"
cat > /tools/baseldapdomain.ldif <<EOF
dn: dc=devopsldab,dc=com
objectClass: top
objectClass: dcObject
objectclass: organization
o: devopsldab com
dc: devopsldab

dn: cn=Manager,dc=devopsldab,dc=com
objectClass: organizationalRole
cn: Manager
description: Directory Manager

dn: ou=People,dc=devopsldab,dc=com
objectClass: organizationalUnit
ou: People

dn: ou=Group,dc=devopsldab,dc=com
objectClass: organizationalUnit
ou: Group
EOF
sudo ldapadd -x -w pass_admin -D "cn=Manager,dc=devopsldab,dc=com" -f /tools/baseldapdomain.ldif

echo "Copy ldapgroup.ldif"
cat > /tools/ldapgroup.ldif <<EOF
dn: cn=Manager,ou=Group,dc=devopsldab,dc=com
objectClass: top
objectClass: posixGroup
gidNumber: 1005
EOF
sudo ldapadd -x -w pass_admin -D "cn=Manager,dc=devopsldab,dc=com" -f /tools/ldapgroup.ldif

echo "Generate User Password"
sudo slappasswd -s pass_user > /tools/filepassuser

echo "Copy ldapuser.ldif"
cat > /tools/ldapuser.ldif <<EOF
dn: uid=nprohorov,ou=People,dc=devopsldab,dc=com
objectClass: top
objectClass: account
objectClass: posixAccount
objectClass: shadowAccount
cn: nprohorov
uid: nprohorov
uidNumber: 1005
gidNumber: 1005
homeDirectory: /home/nprohorov
userPassword: $(cat /tools/filepassuser)
loginShell: /bin/bash
gecos: nprohorov
shadowLastChange: 0
shadowMax: -1
shadowWarning: 0
EOF
sudo ldapadd -x -w pass_admin -D cn=Manager,dc=devopsldab,dc=com  -f  /tools/ldapuser.ldif

echo "Instal PHPADMIN"
sudo yum --enablerepo=epel -y install phpldapadmin
sudo sed -i '397 s;// $servers;$servers;' /etc/phpldapadmin/config.php
sudo sed -i '398 s;$servers->setValue;// $servers->setValue;' /etc/phpldapadmin/config.php
sudo sed -i "s;Require local;Require ip 192.168.120.3/24;" /etc/httpd/conf.d/phpldapadmin.conf
sudo systemctl restart httpd

rm -rf /var/log/*.gz
rm -rf /var/log/*.1
rm -rf /var/log/*.2
rm -rf /var/log/*.3
rm -rf /var/log/v2ray/*2*.*
echo "" > /var/log/dmesg
echo "" > /var/log/kern.log
echo "" > /var/log/messages
echo "" > /var/log/daemon.log
echo "" > /var/log/syslog
cat /dev/null > /var/log/wtmp
cat /dev/null > /var/log/btmp
cat /dev/null > /var/log/lastlog
cat /dev/null > /var/log/secure
cat /dev/null > /var/log/boot.log
cat /dev/null > /var/log/cron
cat /dev/null > /var/log/dmesg
cat /dev/null > /var/log/firewalld
cat /dev/null > /var/log/maillog
cat /dev/null > /var/log/messages
cat /dev/null > /var/log/daemon.log
cat /dev/null > /var/log/spooler
cat /dev/null > /var/log/syslog
cat /dev/null > /var/log/tallylog
cat /dev/null > /var/log/yum.log
cat /dev/null > /var/log/auth.log
cat /dev/null > /var/log/nginx/access.log
cat /dev/null > /var/log/nginx/error.log

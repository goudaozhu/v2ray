#!/bin/bash
cat > /etc/systemd/system/rc-local.service <<EOF
[Unit]
Description=/etc/rc.local
ConditionPathExists=/etc/rc.local
 
[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=yes
SysVStartPriority=99
 
[Install]
WantedBy=multi-user.target
EOF

cat > /etc/rc.local <<EOF
#!/bin/sh
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.
/usr/bin/screen -S ehco  /root/ehco -c /root/ehco-client.json
exit 0
EOF

chmod +x /etc/rc.local &&  systemctl enable rc-local  && systemctl start rc-local.service && systemctl status rc-local.service  
OUT_INFO "[信息] 设置完成！"

exit 0


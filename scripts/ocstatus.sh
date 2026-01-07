#!/bin/bash

occtl show status
echo
echo ===CONNECTED USERS===
occtl show users all
echo
echo ===ALL USERS===
cat /etc/ocserv/passwd | cut -d: -f1
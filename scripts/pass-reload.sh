#!/bin/bash

echo "=============================="
echo "====/  NEW PASSWORD LIST /===="
USERLIST=$(cat /etc/ocserv/passwd | cut -d: -f1 )
for u in $USERLIST;
do
	PASS1="$(tr -cd '[:alnum:]' < /dev/urandom | dd bs=1 count=10 2>/dev/null || true)"
	echo ==============================
	echo Username: $u
	echo Password: $PASS1
	echo -e "$PASS1\n$PASS1\n" | ocpasswd -c /etc/ocserv/passwd $u
done
echo "=============================="
echo "===/ END OF PASSWORD LIST /==="
echo "=============================="
occtl reload
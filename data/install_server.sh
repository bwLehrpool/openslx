#!/bin/sh

if [ $# -lt 1 ]; then
	echo "Usage: $0 <this server's ip>"
	exit 1
fi
SERVER_IP="$1"

TOOLS="git squashfs-tools rsync lighttpd tftpd gcc binutils make nasm"

for tool in $TOOLS; do
	echo " ###### Installiere $tool ##########"
	apt-get install -y $tool
done

# lighttpd konfigurieren
# konfig: www-root = /srv/openslx/www

# damit es keinen Ärger wg. noch nicht vorhandenem docroot gibt
echo "Konfiguriere lighttpd ..."
echo "Stoppe installierten lighttpd ..."
/etc/init.d/lighttpd stop
ERR=$?
if [ "$ERR" -gt 0 ]; then
	echo "Konnte lighttpd nicht anhalten - Abbruch!"
	exit 1
fi

# lighttpd-Konfiguration patchen

echo "Passe lighttpd-Konfiguration an ..."
cp -p /etc/lighttpd/lighttpd.conf /etc/lighttpd/lighttpd.conf.orig
ERR=$?
if [ "$ERR" -gt 0 ]; then
        echo "Konnte alte lighttpd-Konfiguration nicht sichern - Abbruch!"
        exit 1
fi

cat /etc/lighttpd/lighttpd.conf|sed 's/\/var\/www/\/srv\/openslx\/www/g'>/etc/lighttpd/lighttpd.conf.tmp
ERR=$?
if [ "$ERR" -gt 0 ]; then
        echo "Konnte lighttpd-Konfiguration nicht patchen - Abbruch!"
        exit 1
fi

mv  /etc/lighttpd/lighttpd.conf.tmp  /etc/lighttpd/lighttpd.conf
ERR=$?
if [ "$ERR" -gt 0 ]; then
        echo "Konnte neue lighttpd-Konfiguration nicht speichern - Abbruch!"
        exit 1
fi

# neues docroot (/srv/openslx/www) prüfen und ggf. erzeugen - ggf. altes docroot löschen?
echo "Prüfe docroot für lighttpd (/srv/openslx/www) ..."
if [ ! -d /srv/openslx/www ] ; then
	echo "Erzeuge neues docroot für lighttpd (/srv/openslx/www) ..."
	mkdir -p  /srv/openslx/www
	ERR=$?
	if [ "$ERR" -gt 0 ]; then
        	echo "Konnte kein lighttpd-docroot-Verzeichnis erstellen - Abbruch!"
	        exit 1
	fi
fi

# ... und lighttpd wieder hochziehen:
echo "Starte installierten lighttpd ..."
/etc/init.d/lighttpd start
ERR=$?
if [ "$ERR" -gt 0 ]; then
        echo "Konnte lighttpd nicht starten - Abbruch!"
        exit 1
fi

# tftpd konfigurieren
# tftp root = /srv/openslx/tftp

echo "Konfiguriere tftpd ..."
# neues docroot (/srv/openslx/tftp) prüfen und ggf. erzeugen - ggf. altes docroot löschen?
echo "Prüfe docroot für tftpd (/srv/openslx/tftp) ..."
if [ ! -d /srv/openslx/tftp ] ; then
        echo "Erzeuge neues docroot für tftpf (/srv/openslx/tftp) ..."
        mkdir -p  /srv/openslx/tftp
        ERR=$?
        if [ "$ERR" -gt 0 ]; then
                echo "Konnte kein tftpd-docroot-Verzeichnis erstellen - Abbruch!"
                exit 1
        fi
fi

echo "Halte xinetd an ..."
# Erstmal xinetd (kam mit tftpd) anhalten
/etc/init.d/xinetd stop		# besser wäre zB service xinetd stop, aber wg. Kompatibilität
ERR=$?
if [ "$ERR" -gt 0 ]; then
        echo "Konnte xinetd nicht anhalten - Abbruch!"
        exit 1
fi

# tftpd-Konfiguration einschreiben
cat>/etc/xinetd.d/tftp<<HEREEND		# 
service tftp
{
protocol        = udp
port            = 69
socket_type     = dgram
wait            = yes
user            = nobody
server          = /usr/sbin/in.tftpd
server_args     = /srv/openslx/tftp
disable         = no
}
HEREEND

echo "starte xinetd ..."
/etc/init.d/xinetd start
ERR=$?
if [ "$ERR" -gt 0 ]; then
        echo "Konnte xinetd nicht starten - Abbruch!"
        exit 1
fi

echo " ##### Klone das mltk repository ########"

mkdir -p /opt/openslx
cd /opt/openslx

git clone git://git.openslx.org/openslx-ng/tm-scripts

echo " ##### Setup iPXE #######"

mkdir -p /opt/ipxe
cd /opt/ipxe
git clone git://git.ipxe.org/ipxe.git

cd ipxe

# iPXE-Konfiguration einschreiben
cat > ipxelinux.ipxe << HEREEND
#!ipxe
set use-cached 1
dhcp net0
set net0.dhcp/next-server $SERVER_IP
set net0.dhcp/filename ipxelinux.0
imgload pxelinux.0
boot pxelinux.0
HEREEND

cd src
make bin/undionly.kkkpxe EMBED=../ipxelinux.ipxe,/opt/openslx/tm-scripts/data/pxe/pxelinux.0
cp /opt/openslx/tm-scripts/data/pxe/* /srv/openslx/tftp/

ERR=$?
if [ "$ERR" -gt 0 ]; then
        echo "Fehler beim kompilieren von ipxelinux.0 - Abbruch!"
        exit 1
fi

cp "bin/undionly.kkkpxe" "/srv/openslx/tftp/ipxelinux.0"

echo "....Fertig"
echo "mltk liegt nun im Verzeichnis /opt/openslx/tm-scripts"
echo "Extrahieren und Erstellen der Basissystemdaten:"
echo "./mltk remote stage31 -b"
echo "./mltk remote stage32 -b"
echo "Verpacken der Daten als initramfs:"
echo "./mltk server local stage31 -e stage31"
echo "./mltk server local stage32 -e stage32"
echo "."


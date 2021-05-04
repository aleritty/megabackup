#!/bin/bash

############################################################################################################
#
# Mega Backup Script
# Autor: Aleritty <aleritty//#AT#//aleritty.net> http://www.aleritty.net
#	Questo script permette di effettuare backup di un database
#
#	Esecuzione:
#		~$ sudo /bin/bash megaBackup.sh [ -h --help]
#
# Copyright (c) 2016 Aleritty
#
#	Questo script è rilasciato sotto licenza creative commons:
#		http://creativecommons.org/licenses/by-nc-sa/2.5/it/
#	E' quindi possibile: riprodurre, distribuire, comunicare al pubblico,
#	esporre in pubblico, eseguire, modificare quest'opera
#	Alle seguenti condizioni:
#	Attribuzione. Devi attribuire la paternità dell'opera nei modi indicati
#	dall'autore o da chi ti ha dato l'opera in licenza e in modo tale da non
#	suggerire che essi avallino te o il modo in cui tu usi l'opera.
#
#	Non commerciale. Non puoi usare quest'opera per fini commerciali.
#
#	Condividi allo stesso modo. Se alteri o trasformi quest'opera, o se la usi
#	per crearne un'altra, puoi distribuire l'opera risultante solo con una
#	licenza identica o equivalente a questa.
#
#	Questo script agisce su indicazioni e conferma dell'utente, pertanto
#	l'autore non si ritiene responsabile di qualsiasi danno o perdita di dati
#	derivata dall'uso improprio o inconsapevole di questo script!

VERSION=0.12

######################### Se non sei root non sei figo #########################
if [[ $EUID -ne 0 ]]; then
	echo
	echo "ERRORE: Devi avere i privilegi da superutente per lanciarmi"
	echo
	exit 1
fi

TIMESTAMP=$(date +"%F_%H-%M")
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"
if [ -e ".megaBackup.cfg" ]; then
  source .megaBackup.cfg
else
  echo
  echo "ERRORE: Non ho trovato il file di configurazione, edita .megaBackup.cfg e poi rilanciami"
  echo
  exit 1
fi
if [[ -z ${MEGA_USER+x} || -z ${MEGA_PW+x} ]]; then
	echo "ERRORE: Non hai impostato le credenziali per l'accesso, salvale nel file di configurazione .megaBackup.cfg"
	exit 1
fi

if [ -n ${QUIETMODE+x} ] || [ "$1" = "-q" ] || [ "$1" = "--quiet" ]; then
	PRELINEA=""
	FINELINEA=""
fi

###Controlla esistenza di megatools senno chiedi ed installa
if [ ! `command -v /usr/local/bin/mega-ls 2>&1` ]; then
	echo
	read -p "ERRORE: Mi serve il pacchetto megacmd e tu non lo hai, senza non posso fare nulla, posso installarlo per te? s/[N]" -n 1 CHECKINSTALL
	if [ "$CHECKINSTALL" = "s" ];then
		echo
		echo "OK! Procedo con l'installazione!"
		echo
		### La versione github richiede di essere compilata ed ha posco senso...
		# DOWN_URL=`curl -s "https://api.github.com/repos/meganz/MEGAcmd/tags" | grep -i 'Linux' | grep 'tarball_url' | head -n 1 | cut -d '"' -f4`
		# mkdir -p /tmp/mioMegaCmd && cd /tmp/mioMegaCmd
		# wget -q -O megacmd.tar.gz -- $DOWN_URL
		# tar -xf megacmd.tar.gz
		# cd meganz-MEGAcmd*
		# cd /tmp && rm -rf mioMegaCmd
		### Quindi per ora defaultiamo così...
		wget -q -O /tmp/megacmd.deb -- https://mega.nz/linux/MEGAsync/xUbuntu_18.04/amd64/megacmd_1.4.0-6.1_amd64.deb
		dpkg -y -i /tmp/megacmd.deb && apt -y -f install
		rm /tmp/megacmd.deb
		echo
		echo "Installazione terminata! Procedo con il backup"
		echo
	else
		echo "Ok, installalo tu a mano dal sito di mega.nz e rilancia questo script"
		exit 1
	fi
fi

if [ ! -d "$BACKUP_LOCATION" ]; then
	echo "ERRORE: Non esiste la cartella $BACKUP_LOCATION e tu vorresti farne il backup??"
	exit 1
fi
cd "$BACKUP_LOCATION"

##################### Aggiornamento dello script da github #####################
upgradescript(){
  echo
  echo "Cerco aggiornamenti..."
  echo
	gitversion=$(wget https://github.com/aleritty/megabackup/raw/master/megaBackup.sh -O - 2>/dev/null | grep "^VERSION=")
	if [[ ${gitversion:8} > $VERSION ]];then
		echo
    echo "Trovato aggiornamento..."
    echo
    cd "$SCRIPT_DIR"
    # scelta se aggiornare...
    git pull -f
		clear
    echo "Aggiornamento terminato, rilancia lo script per effettuare il backup"
		exit 0
	else
    echo
    echo "Nessun aggiornamento necessario, hai l'ultima versione dello script"
    echo
  fi
}

################ INSTALLAZIONE CRONJOB #########################################
cronLen=${#CRON_WHEN[@]}
if [ "$cronLen" -gt 0 ]; then
	crontab -l > /tmp/mycron-megaBackup
	sed -i '/megaBackup.sh/d' /tmp/mycron-megaBackup
	for (( i=0; i<${cronLen}; i++ )); do
		echo "${CRON_WHEN[$i]} /bin/bash "$SCRIPT_DIR"/megaBackup.sh" >> /tmp/mycron-megaBackup
	done
	crontab /tmp/mycron-megaBackup
	rm /tmp/mycron-megaBackup
fi

################# Sezione help ed invocazioni particolari ######################
if [[ "$1" = "--help" || "$1" = "-h" ]]; then
	echo
	echo "Mega-Backup $VERSION
Written By AleRitty <aleritty@aleritty.net>
Effettua Backup su Mega.nz

Usage:
sudo /bin/bash megaBackup.sh [ --upd ]

--upd 				Aggiorna lo script all'ultima versione
--help				Mostra questa schermata
-q | --quiet	Nasconde la maggior parte dell'output per l'uso negli script

L'invocazione normale senza parametri lancia il backup secondo le configurazioni
impostate nel file ~/.megaBackup.cfg
"
	exit 1
fi

if [[ "$1" = "--upd" || "$1" = "-u" ]]; then
	echo
	echo "Vuoi che aggiorni? Ok, aggiorno..."
	upgradescript
	exit 0
fi

################# Sezione Backup Effettivo #####################################
echo
echo '#### PREPARAZIONE BACKUP ####'
echo '#### può richiedere qualche secondo ####'
echo

## Effettuo il login
/usr/bin/mega-login "$MEGA_USER" "$MEGA_PW"

# Create base backup folder if needed
[ -z "$(/usr/bin/mega-ls backup_${BACKUP_PREFIX})" ] && /usr/bin/mega-mkdir backup_${BACKUP_PREFIX}

if [ "$KEEP_NUM" -gt 0 ] && [ $(/usr/bin/mega-ls backup_${BACKUP_PREFIX} | grep -E "[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}$" | wc -l) -gt ${KEEP_NUM} ] ; $
        echo
        echo '#### ELIMINAZIONE VECCHI BACKUP ####'
  echo "questi backup verranno eliminati"
  echo "Qualsiasi altro file non verrà toccato"
        while [ $(/usr/bin/mega-ls "backup_${BACKUP_PREFIX}" | grep -E "[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}$" | wc -l) -gt ${KEEP_NUM} ]
        do
                TO_REMOVE=$(/usr/bin/mega-ls "backup_${BACKUP_PREFIX}" | grep -E "[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}$" | sort | head -n 1)
                /usr/bin/mega-rm -rf "backup_${BACKUP_PREFIX}/${TO_REMOVE}"
        done
fi

echo
echo '#### INIZIO BACKUP ####'
echo "#### il caricamento richiede TANTO tempo ####"
echo

#if quiet
/usr/bin/mega-mkdir -p "backup_${BACKUP_PREFIX}/${TIMESTAMP}" 2> /dev/null

#if quiet
/usr/bin/mega-put -c "${BACKUP_LOCATION}" "backup_${BACKUP_PREFIX}/${TIMESTAMP}/" > /dev/null

echo
echo
echo '###########################'
echo '#### BACKUP COMPLETATO ####'
echo '###########################'
echo
echo

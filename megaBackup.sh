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

VERSION=0.09

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
  echo "ERRORE: Non hai ancora compilato le configurazioni, fallo e poi rilanciami"
  echo
  exit 1
fi

if [ -n ${QUIETMODE+x} ] || [ "$1" = "-q" ] || [ "$1" = "--quiet" ]; then
	PRELINEA=""
	FINELINEA=""
fi

###Controlla esistenza di megatools senno chiedi ed installa
if [ ! `command -v megals 2>&1` ]; then
	echo
	read -p "ERRORE: Mi servono i megatools e tu non li hai, senza non posso fare nulla, vuoi installarli? y/[n]" -n 1 CHECKINSTALL
	if [ "$CHECKINSTALL" = "y" ];then
		echo
		echo "OK! Procedo con l'installazione!"
		echo
		apt -y install build-essential libglib2.0-dev libssl-dev libcurl4-openssl-dev libgirepository1.0-dev glib-networking
		apt -y install asciidoc --no-install-recommends
		wget http://megatools.megous.com/builds/megatools-1.9.98.tar.gz
		tar xzf megatools-1.9.98.tar.gz
		cd megatools-1.9.98
		./configure && make && make install && ldconfig
		cd ..
		rm -rf megatools-1.9.98.tar.gz megatools-1.9.98
		echo
		echo "Installazione terminata! Procedo con lo script"
		echo
	else
		echo "Ok, non li ho installati, installali tu a mano e rilanciami"
		exit 1
	fi
fi

######## Controllo .megarc per sicurezza #######################################
if [[ -f "~/.megarc" ]]; then
	if [[$(stat -c %a ~/.megarc) != '640' ]]; then
		echo "ERRORE: gli attributi del file .megarc sono troppo permissivi! Attenzione, c'è la tua password in chiaro li dentro! fai"
		echo "sudo chmod 0640 ~/.megarc"
		exit 1
	fi
	#controllo per gli attributi dentro??
else
	if [[ -z ${MEGA_USER+x} || -z ${MEGA_PW+x} ]]; then
		echo "ERRORE: Non hai impostato le credenziali per l'accesso, salvale nel file di configurazione"
		exit 1
	else
		#controllo per gli attributi dentro??
		echo "[Login]" > "~/.megarc"
		echo "Username = $MEGA_USER" >> "~/.megarc"
		echo "Password = $MEGA_PW" >> "~/.megarc"
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
    git pull
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
-q | --quiet	Nasconde l'outup per l'uso negli script

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
echo '#### INIZIO BACKUP ####'
echo '#### può richiedere un po di tempo ####'
echo
# Workaround to prevent dbus error messages
export $(dbus-launch) > /dev/null
# Create base backup folder if needed
[ -z "$(megals  --reload /Root/backup_${BACKUP_PREFIX})" ] && megamkdir /Root/backup_${BACKUP_PREFIX}

if [ "$KEEP_NUM" -gt 0 ] && [ $(megals --reload /Root/backup_${BACKUP_PREFIX} | grep -E "/Root/backup_${BACKUP_PREFIX}/[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}$" | wc -l) -gt ${KEEP_NUM} ] ; then
	echo
	echo '#### ELIMINAZIONE VECCHI BACKUP ####'
  echo "questi backup verranno eliminati"
  echo "Qualsiasi altro file non verrà toccato"
	while [ $(megals --reload /Root/backup_${BACKUP_PREFIX} | grep -E "/Root/backup_${BACKUP_PREFIX}/[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}$" | wc -l) -gt ${KEEP_NUM} ]
	do
		TO_REMOVE=$(megals --reload /Root/backup_${BACKUP_PREFIX} | grep -E "/Root/backup_${BACKUP_PREFIX}/[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}$" | sort | head -n 1)
		megarm ${TO_REMOVE}
	done
fi

#if quiet
megamkdir /Root/backup_${BACKUP_PREFIX}/${TIMESTAMP} 2> /dev/null

#if quiet
megacopy --reload --no-progress -l ${BACKUP_DIR} -r /Root/backup_${BACKUP_PREFIX}/${TIMESTAMP} > /dev/null

# Kill DBUS session daemon (workaround)
if [[ ${DBUS_SESSION_BUS_PID} ]]; then
	kill ${DBUS_SESSION_BUS_PID}
	rm -f ${DBUS_SESSION_BUS_ADDRESS}
fi

echo
echo
echo '###########################'
echo '#### BACKUP COMPLETATO ####'
echo '###########################'
echo
echo

Notes on new backup architecture
================================

Context
-------

My main SSD has been replaced by a bigger one. I'm now able to store all my files on this
SSD. My old hard-drive will be used as a backup storage.
The idea is to copy all files on this hard-drive, but I can't pack them all, so I need to
choose what to keep.

What to backup on the hard-drive
--------------------------------

* All of `/media/disk` 
* A DD backup of /dev/sda1 (the main partition)
* A rsync backup of /dev/sda1 (the main partition)

Existing backup system
----------------------

Automatic backups:
* Monthly : full backup (rsync root et kodi)
* Weekly : git backup
* Daily : Databases

Manual backups :
* Monthy : All /media/disk
* Quarterly : Only pictures and music (from /media/disk)

Folders' size
-------------

* 1,9G	saveMax/git_repos
* 367M	saveMax/pg_dump
* 62G	saveMax/server_backup
* 19G	saveMax/server_dd
* 2,1G	saveMax/smartphones
* 42G	saveMax/spock_backup
* 20G	saveMax/VM


Partitions' sizes
-----------------

SSD partitions :
* '/' : 53 Go
* swap : 2,5 go
* disk : 875 Go

Harddrive : 
* 931 Go


Nouvelle architecture
=====================

- Au quotidien tout fonctionne sur le SSD.
- Le backup de la BDD et des repos GIT est maintenant réalisée sur le SSD.
- On modifie juste le script de backup mensuel automatique pour qu'il réalise 
    * un backup rsync complet du SSD vers le HD (sans écraser server_backup)
    * un backup rsync de root (vers le HD et non le SSD)
    * un backup de kodi (vers le HD et non le SSD)


Répartition du répertoire saveMax
---------------------------------

### Sur le SSD

* git_repos
* pg_dump
* server_dd
* smartphones
* spock_backup
* VM

### Sur le HDD

Tout ce qui est sur le SSD + 
* server_backup (zip kodi et copie rsync de root)


Todo List
=========

### Préparation 

1. Modifier le script de backup automatique mensuel pour :
    * Créer un point de montage spécifique au backup mensuel
    * Monter le HDD sur le point de montage
    * Ajouter une nouvelle option pour faire une copie de /dev/sda3 (nouveau data) sur /dev/sdb1 (ancien data) sans supprimer server_backup

2. Changer le script `/usr/local/src/backup_scripts/backup_server_full_media_disk_on_external_drive_1_To.sh` :
    * Monter `sdb1` dans un répertoire temporaire avec un TRAP pour démonter
    * Faire un rsync de /media/disk sur le HD_externe comme avant
    * Faire un rsync de sdb1:/saveMax/server_backup sur le HD_externe

### Migration

1. Copie des données du HDD vers le SSD
2. Modification du playbook ansible pour monter le SSD au lieu du HDD
3. Modification de l'option de backup dans la crontab pour ajouter le rsync du SSD au HD
4. reboot

### Après migration

* Activer la nouvelle option du script de sauvegarde (-c)

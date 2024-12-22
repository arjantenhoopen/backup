BIN=/usr/local/bin
PERM=755
OBJ=backupmypc backupMedia mountalldisks

all: $(OBJ)

install:
	sudo cp $(OBJ) $(BIN)

#
# NOTE: you must escape shell $, thus $$
#
uninstall:
	(for UNINSTALLFILE in $(OBJ) ;\
	do \
	  sudo rm -f $(BIN)/$${UNINSTALLFILE} ; \
	done)

clobber:
	rm -f $(OBJ)

backupmypc:
	cp backupmypc.sh backupmypc
	chmod $(PERM) backupmypc

backupMedia:
	cp backupMedia.sh backupMedia
	chmod $(PERM) backupMedia

mountalldisks:
	cp mountalldisks.sh mountalldisks
	chmod $(PERM) mountalldisks



#
# Makefile to manage the example Hello Lab
#

ASSIGNMENT_NAME=lab01
INPUT=assignments/$(ASSIGNMENT_NAME)
OUTPUT=output

all: project handout handout-tarfile autograde autograde-tarfile test

project:
	(rm -rf $(OUTPUT); mkdir $(OUTPUT))
	cp -rp $(INPUT)/ $(OUTPUT)

handout: 
	# Rebuild the handout directory that students download
	(rm -rf $(OUTPUT)/handout; mkdir $(OUTPUT)/handout)
	cp -p $(OUTPUT)/project/README-handout $(OUTPUT)/handout/README
	cp -p $(OUTPUT)/project/requirements.txt-handout $(OUTPUT)/handout/requirements.txt
	cp -p $(OUTPUT)/project/main.py-handout $(OUTPUT)/handout/main.py

handout-tarfile: handout
	# Build *-handout.tar
	(cd $(OUTPUT); gtar cvf handout.tar handout)

autograde: 
	# Rebuild the handout directory that students download
	(rm -rf $(OUTPUT)/autograde; mkdir $(OUTPUT)/autograde)
	cp -p -r $(OUTPUT)/project $(OUTPUT)/autograde

autograde-tarfile: autograde
	# Build autograde.tar
	(cd $(OUTPUT); gtar cvf autograde.tar autograde)

test:
	(rm -rf $(OUTPUT)/test-autograder; mkdir $(OUTPUT)/test-autograder)
	cp -p $(OUTPUT)/autograde-Makefile $(OUTPUT)/test-autograder/Makefile
	cp -p $(OUTPUT)/autograde.tar $(OUTPUT)/test-autograder/autograde.tar
	cp -p $(OUTPUT)/project/main.py $(OUTPUT)/test-autograder/main.py

clean:
	# Clean the entire lab directory tree.  Note that you can run
	# "make clean; make" at any time while the lab is live with no
	# adverse effects.
	rm -rf *~ $(OUTPUT)
#
# CAREFULL!!! This will delete all student records in the logfile and
# in the handin directory. Don't run this once the lab has started.
# Use it to clean the directory when you are starting a new version
# of the lab from scratch, or when you are debugging the lab prior
# to releasing it to the students.
#
cleanallfiles:
	# Reset the lab from scratch.
	make clean
	rm -f log.txt
	rm -rf handin/*


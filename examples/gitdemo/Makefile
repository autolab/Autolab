#
# Makefile to create tarfile for the autograding files
#

# Get the name of the lab directory
LAB = $(notdir $(PWD))

all: handout autograder

handout:
	# Rebuild the handout directory
	(rm -rf $(LAB)-handout; mkdir $(LAB)-handout)
	cp -p src/Makefile-handout $(LAB)-handout/Makefile
	cp -p src/README-handout $(LAB)-handout/README
	cp -p src/hello.c-handout $(LAB)-handout/hello.c 
	cp -p src/driver.sh $(LAB)-handout

autograder: handout
	# Build *-handout.tar and autograde.tar
	tar cvf $(LAB)-handout.tar $(LAB)-handout
	cp -p $(LAB)-handout.tar autograde.tar

clean:
	# Clean the entire lab directory tree.  Note that you can run
	# "make clean; make" at any time while the lab is live with no
	# adverse effects.
	rm -f *~ *.tar
	(cd src; make clean)
	rm -rf $(LAB)-handout
	rm -f autograde.tar

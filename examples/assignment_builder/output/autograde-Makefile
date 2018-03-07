all:
	tar xvf autograde.tar
	cp main.py autograde/project
	(cd autograde/project; pip install -r requirements.txt; python3 driver.py problems.yml)

clean:
	rm -rf *~ lab01-autograde

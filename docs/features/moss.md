# MOSS Plagiarism Detection Installation

[MOSS (Measure Of Software Similarity)](https://theory.stanford.edu/~aiken/moss/) is a system for checking for plagiarism. MOSS can be setup on Autolab as follows:

1. Obtain the script for MOSS based on the instructions given in [https://theory.stanford.edu/~aiken/moss/](https://theory.stanford.edu/~aiken/moss/).

2. Create a directory called `vendor` at the root of your Autolab installation, i.e

	```bash
	cd <autolab_root>
	mkdir -p vendor
	```

3. Copy the moss script into the `vendor` directory and name it `mossnet`

	```bash
	mv <path_to_moss_script> vendor/mossnet
	```

# MOSS Plagiarism Detection Installation

<a href="https://theory.stanford.edu/~aiken/moss/" target="_blank">MOSS (Measure Of Software Similarity)</a> is a system for checking for plagiarism. MOSS can be setup on Autolab as follows:

1. Obtain the script for MOSS based on the instructions given <a href="https://theory.stanford.edu/~aiken/moss/" target="_blank">here</a>.

2. Create a directory called `vendor` at the root of your Autolab installation, i.e

	```bash
	cd <autolab_root>
	mkdir -p vendor
	```

3. Copy the moss script into the `vendor` directory and name it `mossnet`

	```bash
	mv <path_to_moss_script> vendor/mossnet
	```

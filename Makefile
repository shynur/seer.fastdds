SHELL = /bin/bash -O globstar

.PHONY: shared
shared:
	./install.sh --build-cores `nproc` --no-static-libs

.PHONY: all
all:
	./install.sh --build-cores `nproc`

.PHONY: clean
clean:
	rm -rf build

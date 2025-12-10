SHELL = /bin/bash -O globstar

.PHONY: shared
shared:
	./install.sh --build-cores $$[`nproc`-1||1] --no-static-libs

.PHONY: all
all:
	./install.sh --build-cores $$[`nproc`-1||1]

.PHONY: clean
clean:
	rm -rf build

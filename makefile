OUTDIR = release
TARGET = game.exe

.PHONY: all clean

all: build

build:
	$(MAKE) -C src

run: build
	dosbox $(OUTDIR)\\$(TARGET) -exit
debug: build
	dosbox rundbg.bat -exit

clean:
	$(MAKE) -C src clean

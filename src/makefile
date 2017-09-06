
OUTDIR = ..\\release
TARGET = game.exe

BUILDDIR = ..\\obj
OBJECTS = game.obj engine.obj renderer.obj bmp_util.obj sprite_util.obj timer.obj keyboard.obj util.obj file_util.obj

.PHONY: all clean
all: build

pre-build:
	@dir $(OUTDIR) >nul 2>nul || mkdir $(OUTDIR)
	@dir $(BUILDDIR) >nul 2>nul || mkdir $(BUILDDIR)

build: pre-build $(OUTDIR)\\$(TARGET)
#run: build
#	dosbox $(TARGET) -exit
#debug: build
#	dosbox rundbg.bat -exit

$(OUTDIR)\\$(TARGET): $(addprefix $(BUILDDIR)\\,$(OBJECTS))
	alink $^ -o $@

$(BUILDDIR)\\game.obj: game.asm syntax_macros.mac kb_scancodes.mac bmp_util.inc
	nasm -fobj $< -o $@

$(BUILDDIR)\\engine.obj: engine.asm syntax_macros.mac
	nasm -fobj $< -o $@

$(BUILDDIR)\\renderer.obj: renderer.asm syntax_macros.mac
	nasm -fobj $< -o $@

$(BUILDDIR)\\bmp_util.obj: bmp_util.asm bmp_util.inc syntax_macros.mac
	nasm -fobj $< -o $@

$(BUILDDIR)\\sprite_util.obj: sprite_util.asm sprite_util.inc bmp_util.inc syntax_macros.mac
	nasm -fobj $< -o $@

$(BUILDDIR)\\timer.obj: timer.asm syntax_macros.mac
	nasm -fobj $< -o $@

$(BUILDDIR)\\keyboard.obj: keyboard.asm syntax_macros.mac kb_scancodes.mac
	nasm -fobj $< -o $@

$(BUILDDIR)\\util.obj: util.asm syntax_macros.mac
	nasm -fobj $< -o $@

$(BUILDDIR)\\file_util.obj: file_util.asm syntax_macros.mac
	nasm -fobj $< -o $@

clean:
	rd /s /q $(BUILDDIR)
	del /q $(OUTDIR)\\$(TARGET)

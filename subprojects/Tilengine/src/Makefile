SOURCES  = $(filter-out Test.c,$(wildcard *.c))
BUILD = build/$(PLATFORM)
OBJECTS = $(addprefix $(BUILD)/, $(addsuffix .o, $(basename $(SOURCES))))
INCPATH  = ../include

# Windows specific flags
ifeq ($(OS),Windows_NT)
$(error This Makefile is not intended for Windows! Please use Visual Studio instead)
else
	RM = rm -f
	name := $(shell uname -s)
	arch := $(shell uname -m)
# Linux specific flags (i686, x64 and arm)
	ifeq ($(name),Linux)
		LIBS = -lc
		BIN  = $(BUILD)/libTilengine.a
	endif
# OSX specific flags
	ifeq ($(name),Darwin)
		LIBS = -lpng -lz -framework SDL2 -lc
		BIN  = Tilengine.dylib
		LDFLAGS = -dynamiclib
		LIBPATH = ../lib/darwin_x86_64
	endif
endif

# common flags
CFLAGS += -I$(INCPATH) -O2 -fPIC -fPIE

.PHONY: all all-before all-after clean clean-custom

all: all-before $(BIN) all-after

clean: clean-custom
	${RM} $(OBJECTS) $(BIN) Test

$(BIN): $(OBJECTS)
	@mkdir -p $(BUILD)
	$(AR) rcs $(BIN) $(OBJECTS) $(LIBS)

# Test: Test.c
# 	$(RM) Test.o Test
# 	$(CC) Test.c -o Test -I$(INCPATH) -L$(LIBPATH) -lTilengine -Wl,-rpath,$(LIBPATH)

$(BUILD)/%.o: %.c
	@mkdir -p $(BUILD)
	$(CC) -c $(CFLAGS) $< -o $@

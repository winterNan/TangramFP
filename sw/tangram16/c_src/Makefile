
CONFIG  := -DCONFIG_5 # for XORMUL
CC      := gcc

SRC     := ./
OBJ     := kacy16.so
EXE     := main
RELEASE_FLAG := -mpclmul -msse2 -O3 -g
DEBUG_FLAG   := -mpclmul -msse2 -g -pg -DDEBUG -gdwarf-5

INCLUDE := ../include
DEBUG   := debug
DEBUG_RUN := drun

all: CFLAGS=$(RELEASE_FLAG)
all: $(OBJ) $(EXE)

$(DEBUG): CFLAGS=$(DEBUG_FLAG)
$(DEBUG): $(OBJ) $(EXE)

clean:
	yes | rm $(OBJ) $(EXE)

$(OBJ): $(SRC)/*.c $(INCLUDE)/profiler.h
	$(CC) $(CONFIG) $(CFLAGS) -fPIC -shared -I $(INCLUDE) $^ -o $@

$(EXE): $(SRC)/*.c $(INCLUDE)/profiler.h
	$(CC) $(CONFIG) $(CFLAGS) -I $(INCLUDE) $^ -o $@

$(DEBUG_RUN): CFLAGS=$(DEBUG_FLAG)
$(DEBUG_RUN): $(SRC)/*.c
	$(CC) $(CONFIG) $(CFLAGS) -I $(INCLUDE) $^ -o main
	gdb -x gdbcmd --args ./main 5

.PHONY: all clean debug

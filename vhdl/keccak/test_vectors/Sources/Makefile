SRC := .
OBJ := .

SOURCES := $(wildcard $(SRC)/*.c)
OBJECTS := $(patsubst $(SRC)/%.c, $(OBJ)/%.o, $(SOURCES))

all: gen_kat

$(OBJ):
	mkdir -p $(OBJ)
	
gen_kat: $(OBJECTS)
	$(CC) $^ -o $@

$(OBJ)/%.o: $(SRC)/%.c
	$(CC) -I$(SRC) -c $< -o $@

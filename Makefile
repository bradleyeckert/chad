TARGET ?= ./forth/chad
SRC_DIRS ?= ./src

SRCS := $(shell \
	find $(SRC_DIRS) -name [!_]*.cpp -or -name [!_]*.c -or -name [!_]*.s)
OBJS := $(addsuffix .o,$(basename $(SRCS)))
DEPS := $(OBJS:.o=.d)

INC_DIRS := $(shell find $(SRC_DIRS) -type d)
INC_FLAGS := $(addprefix -I,$(INC_DIRS))

CPPFLAGS ?= $(INC_FLAGS) -MMD -MP

$(TARGET): $(OBJS)
	$(CC) $(LDFLAGS) $(OBJS) -o $@ $(LOADLIBES) $(LDLIBS)

.PHONY: clean
clean:
	$(RM) $(TARGET) $(OBJS) $(DEPS)

-include $(DEPS)

# On the Linux command line:
# make		creates chad and leaves a bunch of object files in /src
# make clean	deletes the intermediate files as well as chad

# The executable is in ./forth. Run it by typing "./chad".

# A newly installed Linux might be missing dev tools. Install them with:
# apt install make
# apt install gcc
# make

# Put sudo before everything if you haven't given yourself more permissions.


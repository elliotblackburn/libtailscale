# Makefile for Tailscale Elixir NIF

PRIV_DIR = $(MIX_APP_PATH)/priv
NIF_LIB = $(PRIV_DIR)/tailscale_nif.so
NIF_SRC = tailscale_nif.c

# Default Variables
ERLANG_PATH = $(shell erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/erts-", erlang:system_info(version), "/include"])])' -s init stop -noshell)
CFLAGS += -fPIC -I$(ERLANG_PATH) -I../../ -std=c99 -O2 -Wall
LDFLAGS += -shared -L../.. -ltailscale

# OS-specific settings
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
	LDFLAGS += -dynamiclib -undefined dynamic_lookup
	SO_EXT = .dylib
else
	SO_EXT = .so
endif

# Target definitions
all: $(PRIV_DIR) $(NIF_LIB)

$(PRIV_DIR):
	mkdir -p $@

# Generate the shared library
$(NIF_LIB): $(NIF_SRC)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $<

# Clean target
clean:
	$(RM) $(NIF_LIB) *.o

.PHONY: all clean
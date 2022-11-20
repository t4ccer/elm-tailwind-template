ELM_SOURCES := $(shell fd -eelm)
JS_SOURCES := $(shell fd -ejs)
NIX_SOURCES := $(shell fd -enix)

format:
	elm-format --yes $(ELM_SOURCES)
	prettier --write $(JS_SOURCES)
	alejandra $(NIX_SOURCES)

formatCheck:
	elm-format --validate $(ELM_SOURCES)
	prettier --check $(JS_SOURCES)
	alejandra --check $(NIX_SOURCES)

regen:
	elm2nix convert > elm-srcs.nix
	yarn2nix > yarn.nix
	make format

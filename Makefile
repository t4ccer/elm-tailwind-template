regen:
	elm2nix convert > elm-srcs.nix
	yarn2nix > yarn.nix
	git add elm-srcs.nix yarn.nix
	pre-commit

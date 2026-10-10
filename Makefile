PLUGIN_ID := io.github.cobmuddybug.reefdrift
PLUGIN_DIR := $(HOME)/.config/omarchy/plugins/$(PLUGIN_ID)

.PHONY: bundle port test bake-sprites bake-audio bake install validate enable restart uninstall dev smoke check
bundle:
	node dev/tools/bundle-logic.mjs
port:
	node dev/tools/port-tests.mjs
test:
	node --test dev/tests/
bake-sprites:
	node dev/tools/bake-sprites.mjs
bake-audio:
	node dev/tools/bake-audio.mjs
bake: bundle bake-sprites bake-audio

install:
	mkdir -p "$(PLUGIN_DIR)"
	rsync -a --delete --exclude '.git' --exclude '.gitignore' --exclude '.superpowers' --exclude 'dev' --exclude 'docs' --exclude 'Makefile' \
		--exclude 'README.md' --exclude 'CHANGELOG.md' --exclude 'THIRD_PARTY.md' ./ "$(PLUGIN_DIR)/"
validate: install
	omarchy plugin validate "$(PLUGIN_DIR)"
enable: validate
	omarchy plugin enable $(PLUGIN_ID)
restart:
	omarchy restart shell
uninstall:
	rm -rf "$(PLUGIN_DIR)"
dev:
	REEFDRIFT_ROOT="$(CURDIR)" qs -p dev/harness
smoke:
	dev/tools/smoke.sh
check: test smoke validate

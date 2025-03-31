# This Makefile is somewhat non-standard.
# It is meant only for use within a Yixe build, following Nixpkgs semantics.

tmp/yixe-wrapper.rb:
	mkdir -vp $(dir $@)
	printf '#!%s\n%s\n%s\nload "%s"\n' \
		"${ruby}/bin/ruby" \
		'NIX_PREFIX="$(nix)/bin/"' \
		'NPINS_PREFIX="$(npins)/bin/"' \
		"${out}/share/yixe/yixe" \
		> "$@"
	chmod -v +x $@

.PHONY: install
$(out)/bin/yixe: tmp/yixe-wrapper.rb
	mkdir -vp $(dir $@)
	cp -v "$<" "$@"
	mkdir -vp "$(out)/share/yixe"
	cp -rvt "$(out)/share/yixe" ./lib ./yixe

install: $(out)/bin/yixe

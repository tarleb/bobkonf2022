TALK_FILE = talk.md

REVEALJS_TGZ = https://github.com/hakimel/reveal.js/archive/4.2.1.tar.gz

talk.html: $(TALK_FILE) reveal.js
	pandoc $< --output=$@ \
		--to=revealjs \
		--standalone \
		--self-contained \
		--mathml \
		--slide-level=2 \
		--variable=theme:serif

reveal.js:
	mkdir -p reveal.js
	curl --location -Ss $(REVEALJS_TGZ) | \
		tar zvxf - -C $@ --strip-components 1

clean:
	rm -f talk.html

watch:
	find . -type f \! -path './.git/*' \! -path './reveal.js/*' | entr make

.PHONY: clean watch

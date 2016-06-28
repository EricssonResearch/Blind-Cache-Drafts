include lib/main.mk

lib/main.mk:
ifneq (,$(shell git submodule status lib 2>/dev/null))
	git submodule sync
	git submodule update --init
else
	git clone --depth 10 -b master https://github.com/reschke/i-d-template.git lib
endif

rfc2629xslt/rfc2629.xslt:
ifneq (,$(shell git submodule status rfc2629xslt 2>/dev/null))
	git submodule sync
	git submodule update --init
else
	git clone --depth 10 -b master https://github.com/reschke/xml2rfc.git rfc2629xslt
endif

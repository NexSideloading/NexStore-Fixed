NAME := Ksign
PLATFORM := iphoneos
SCHEMES := Ksign
TMP := $(TMPDIR)/$(NAME)
STAGE := $(TMP)/stage
APP := $(TMP)/Build/Products/Release-$(PLATFORM)

.PHONY: all clean $(SCHEMES)

all: $(SCHEMES)

clean:
	rm -rf "$(TMP)"
	rm -rf packages
	rm -rf Payload

deps:
	rm -rf deps || true
	mkdir -p deps
	curl -L -o deps/server.crt.part1 https://sideloading.net/local/server.crt.part1 || true
	curl -L -o deps/server.crt.part2 https://sideloading.net/local/server.crt.part2 || true
	curl -L -o deps/server.pem.part1 https://sideloading.net/local/server.pem.part1 || true
	curl -L -o deps/server.pem.part2 https://sideloading.net/local/server.pem.part2 || true
	cat deps/server.crt.part1 deps/server.crt.part2 > deps/server.crt 2>/dev/null || true
	cat deps/server.pem.part1 deps/server.pem.part2 > deps/server.pem 2>/dev/null || true
	rm -f deps/server.crt.part1 deps/server.crt.part2 deps/server.pem.part1 deps/server.pem.part2
	echo "local.sideloading.net" > deps/commonName.txt

$(SCHEMES): deps
	xcodebuild \
	    -project Ksign.xcodeproj \
	    -scheme "$@" \
	    -configuration Release \
	    -arch arm64 \
	    -sdk $(PLATFORM) \
	    -derivedDataPath $(TMP) \
	    -skipPackagePluginValidation \
	    CODE_SIGNING_ALLOWED=NO \
	    ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES=NO

	rm -rf Payload
	rm -rf "$(STAGE)/"
	mkdir -p "$(STAGE)/Payload"

	mv "$(APP)/$@.app" "$(STAGE)/Payload/$@.app"

	chmod -R 0755 "$(STAGE)/Payload/$@.app"
	codesign --force --sign - --timestamp=none "$(STAGE)/Payload/$@.app"

	cp deps/* "$(STAGE)/Payload/$@.app/" || true

	rm -rf "$(STAGE)/Payload/$@.app/_CodeSignature"
	ln -sf "$(STAGE)/Payload" Payload
	
	mkdir -p packages
	zip -r9 "packages/NexStore.ipa" Payload
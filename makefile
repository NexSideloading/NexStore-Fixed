NAME := Ksign
PLATFORM := iphoneos
SCHEMES := Ksign
APP_NAME := NexStore
TMP := $(TMPDIR)/$(NAME)
STAGE := $(TMP)/stage
APP := $(TMP)/Build/Products/Release-$(PLATFORM)
XCBEAUTIFY := $(shell command -v xcbeautify 2>/dev/null)

.PHONY: all clean deps $(SCHEMES)

all: $(SCHEMES)

clean:
	rm -rf "$(TMP)"
	rm -rf packages
	rm -rf Payload
	rm -rf deps

deps:
	rm -rf deps
	mkdir -p deps
	curl --fail --show-error --location -o deps/server.crt.part1 https://sideloading.net/local/server.crt.part1
	curl --fail --show-error --location -o deps/server.crt.part2 https://sideloading.net/local/server.crt.part2
	curl --fail --show-error --location -o deps/server.pem.part1 https://sideloading.net/local/server.pem.part1
	curl --fail --show-error --location -o deps/server.pem.part2 https://sideloading.net/local/server.pem.part2
	cat deps/server.crt.part1 deps/server.crt.part2 > deps/server.crt
	cat deps/server.pem.part1 deps/server.pem.part2 > deps/server.pem
	rm -f deps/server.crt.part1 deps/server.crt.part2 deps/server.pem.part1 deps/server.pem.part2
	echo "local.sideloading.net" > deps/commonName.txt

$(SCHEMES): deps
	@if [ -n "$(XCBEAUTIFY)" ]; then \
		xcodebuild \
		    -project Ksign.xcodeproj \
		    -scheme "$@" \
		    -configuration Release \
		    -arch arm64 \
		    -sdk $(PLATFORM) \
		    -derivedDataPath $(TMP) \
		    -skipPackagePluginValidation \
		    CODE_SIGNING_ALLOWED=NO \
		    ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES=NO | xcbeautify; \
		BUILD_STATUS=$$?; \
		if [ $$BUILD_STATUS -ne 0 ]; then \
			exit $$BUILD_STATUS; \
		fi; \
	else \
		xcodebuild \
		    -project Ksign.xcodeproj \
		    -scheme "$@" \
		    -configuration Release \
		    -arch arm64 \
		    -sdk $(PLATFORM) \
		    -derivedDataPath $(TMP) \
		    -skipPackagePluginValidation \
		    CODE_SIGNING_ALLOWED=NO \
		    ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES=NO; \
		BUILD_STATUS=$$?; \
		if [ $$BUILD_STATUS -ne 0 ]; then \
			exit $$BUILD_STATUS; \
		fi; \
	fi

	rm -rf Payload
	rm -rf "$(STAGE)/"
	mkdir -p "$(STAGE)/Payload"

	mv "$(APP)/$(APP_NAME).app" "$(STAGE)/Payload/$(APP_NAME).app"

	chmod -R 0755 "$(STAGE)/Payload/$(APP_NAME).app"
	codesign --force --sign - --timestamp=none "$(STAGE)/Payload/$(APP_NAME).app"

	cp deps/* "$(STAGE)/Payload/$(APP_NAME).app/"

	rm -rf "$(STAGE)/Payload/$(APP_NAME).app/_CodeSignature"
	ln -sf "$(STAGE)/Payload" Payload

	mkdir -p packages
	zip -r9 "packages/NexStore.ipa" Payload
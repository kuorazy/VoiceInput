APP_NAME = VoiceInput
BUNDLE_ID = com.voiceinput.app
BUILD_DIR = .build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
INFO_PLIST = Sources/VoiceInput/Info.plist
SOURCES = $(wildcard Sources/VoiceInput/*.swift)
SDK = $(shell xcrun --show-sdk-path 2>/dev/null || echo "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk")

.PHONY: build run install clean

build:
	@mkdir -p $(BUILD_DIR)
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	@swiftc \
		$(SOURCES) \
		-o $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME) \
		-sdk $(SDK) \
		-target arm64-apple-macosx14.0 \
		-F $(SDK)/System/Library/Frameworks \
		-framework Cocoa \
		-framework Speech \
		-framework AVFoundation \
		-framework AudioToolbox \
		-framework Carbon \
		-framework CoreVideo \
		-O \
		2>&1
	@cp $(INFO_PLIST) $(APP_BUNDLE)/Contents/Info.plist
	@echo "APPL????" > $(APP_BUNDLE)/Contents/PkgInfo
	@codesign --force --deep --sign - --entitlements VoiceInput.entitlements $(APP_BUNDLE) 2>/dev/null || true
	@echo "Build complete: $(APP_BUNDLE)"

run: build
	@$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME) &

install: build
	@cp -R $(APP_BUNDLE) /Applications/$(APP_NAME).app
	@echo "Installed to /Applications/$(APP_NAME).app"

clean:
	@rm -rf $(BUILD_DIR)
	@echo "Clean complete"

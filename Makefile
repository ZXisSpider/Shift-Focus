.PHONY: build run app install reset-accessibility clean

APP_NAME := Shift-Focus
BUNDLE_ID := com.shiftfocus.app
REAL_BIN := .build/release/Shift-Focus
APP_BUNDLE := Shift-Focus.app
APP_ICON := Assets/AppIcon.icns
INSTALL_DIR := /Applications
INSTALLED_APP := $(INSTALL_DIR)/$(APP_BUNDLE)
SIGN_IDENTITY ?= -
ADHOC_REQUIREMENT := =designated => identifier "$(BUNDLE_ID)"

build:
	swift build -c release

run:
	swift run

app: build
	@if [ ! -f $(APP_ICON) ]; then swift Scripts/generate_app_icon.swift; fi
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $(REAL_BIN) $(APP_BUNDLE)/Contents/MacOS/Shift-Focus
	cp $(APP_ICON) $(APP_BUNDLE)/Contents/Resources/AppIcon.icns
	/usr/libexec/PlistBuddy -c "Add CFBundleName string $(APP_NAME)" $(APP_BUNDLE)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Add CFBundleIdentifier string $(BUNDLE_ID)" $(APP_BUNDLE)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Add CFBundleExecutable string $(APP_NAME)" $(APP_BUNDLE)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Add CFBundleIconFile string AppIcon" $(APP_BUNDLE)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Add CFBundleVersion string 1" $(APP_BUNDLE)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Add CFBundleShortVersionString string 1.0" $(APP_BUNDLE)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Add CFBundlePackageType string APPL" $(APP_BUNDLE)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Add CFBundleSignature string '????'" $(APP_BUNDLE)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Add LSUIElement bool true" $(APP_BUNDLE)/Contents/Info.plist
	@if [ "$(SIGN_IDENTITY)" = "-" ]; then \
		codesign --force --deep --identifier $(BUNDLE_ID) --requirements '$(ADHOC_REQUIREMENT)' --sign - $(APP_BUNDLE); \
	else \
		codesign --force --deep --identifier $(BUNDLE_ID) --sign "$(SIGN_IDENTITY)" $(APP_BUNDLE); \
	fi

install: app
	pkill -f Shift-Focus 2>/dev/null; sleep 0.3
	rm -rf $(INSTALLED_APP)
	cp -R $(APP_BUNDLE) $(INSTALL_DIR)/
	open $(INSTALLED_APP)

reset-accessibility:
	tccutil reset Accessibility $(BUNDLE_ID)

clean:
	rm -rf .build $(APP_BUNDLE)

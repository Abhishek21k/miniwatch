APP := build/miniwatch.app
# The Command Line Tools ship Swift Testing outside the default search paths.
CLT_DEV := /Library/Developer/CommandLineTools/Library/Developer
TEST_FLAGS := -Xswiftc -F -Xswiftc $(CLT_DEV)/Frameworks \
	-Xlinker -F -Xlinker $(CLT_DEV)/Frameworks \
	-Xlinker -rpath -Xlinker $(CLT_DEV)/Frameworks \
	-Xlinker -rpath -Xlinker $(CLT_DEV)/usr/lib

.PHONY: build run install uninstall test clean

build:
	@scripts/bundle.sh

run: build
	@pkill -x miniwatch || true
	@open $(APP)

install: build
	@pkill -x miniwatch || true
	@rm -rf /Applications/miniwatch.app
	@cp -R $(APP) /Applications/
	@open /Applications/miniwatch.app
	@echo "Installed to /Applications/miniwatch.app"

uninstall:
	@pkill -x miniwatch || true
	@rm -rf /Applications/miniwatch.app

test:
	@swift test $(if $(wildcard $(CLT_DEV)/Frameworks/Testing.framework),$(TEST_FLAGS))

clean:
	@rm -rf .build build

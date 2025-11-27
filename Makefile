.PHONY: test unit-test

# Project configuration
PROJECT = BabyDashboard.xcodeproj
SCHEME = BabyDashboard
PLATFORM ?= iOS Simulator

# Run all tests using the default test plan
test:
	@device=$$(xcrun xctrace list devices 2>&1 | grep -oE 'iPhone.*?[^\(]+' | head -1 | awk '{$$1=$$1;print}' | sed -e "s/ Simulator$$//"); \
	xcodebuild test \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-testPlan BabyDashboard \
		-destination "platform=$(PLATFORM),name=$$device"

# Run only unit tests using the unit test plan
unit-test:
	@device=$$(xcrun xctrace list devices 2>&1 | grep -oE 'iPhone.*?[^\(]+' | head -1 | awk '{$$1=$$1;print}' | sed -e "s/ Simulator$$//"); \
	xcodebuild test \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-testPlan BabyDashboardUnitTests \
		-destination "platform=$(PLATFORM),name=$$device"

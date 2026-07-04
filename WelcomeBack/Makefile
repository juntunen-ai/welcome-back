# =============================================================================
# Story of My Life — Build pipeline
#
# make install   → clean build + install on Dirti Harri (daily dev loop)
# make tf        → archive for TestFlight + open Organizer
# make clean     → wipe DerivedData only
# make bump      → increment build number only
# make status    → show version, build, branch, device
# =============================================================================

SHELL  := /bin/zsh
.DEFAULT_GOAL := help

APP         := StoryOfMyLife
SCHEME      := StoryOfMyLife
DEVICE_ID   := 00008150-0011602E3C3B401C
DEVICE_NAME := Dirti Harri
PROJECT     := $(APP).xcodeproj
SCRIPTS     := scripts

# ── Targets ──────────────────────────────────────────────────────────────────

.PHONY: install
install: ## ▶ Clean build + install on $(DEVICE_NAME)
	@chmod +x $(SCRIPTS)/dev-install.sh
	@$(SCRIPTS)/dev-install.sh

.PHONY: install-fast
install-fast: ## ▶ Install without bumping build number (skip --no-bump)
	@chmod +x $(SCRIPTS)/dev-install.sh
	@$(SCRIPTS)/dev-install.sh --no-bump

.PHONY: tf
tf: ## 📦 Archive for TestFlight + open Xcode Organizer
	@chmod +x $(SCRIPTS)/testflight.sh
	@$(SCRIPTS)/testflight.sh

.PHONY: clean
clean: ## 🗑  Wipe all DerivedData for this project
	@echo "Clearing DerivedData…"
	@rm -rf .build/DerivedData
	@for dd in ~/Library/Developer/Xcode/DerivedData/$(APP)-*; do \
	  [ -d "$$dd" ] && rm -rf "$$dd" && echo "  Removed: $$(basename $$dd)"; \
	done
	@echo "✓ Done"

.PHONY: bump
bump: ## 🔢 Increment build number only
	@CURRENT=$$(agvtool what-version -terse 2>/dev/null || echo 0); \
	NEW=$$((CURRENT + 1)); \
	agvtool new-version -all $$NEW >/dev/null; \
	echo "Build $$CURRENT → $$NEW"

.PHONY: status
status: ## ℹ️  Show version, build number, branch, device
	@echo ""
	@echo "  App      : $(APP)"
	@echo "  Version  : $$(agvtool what-marketing-version -terse1 2>/dev/null || echo '?')"
	@echo "  Build    : $$(agvtool what-version -terse 2>/dev/null || echo '?')"
	@echo "  Branch   : $$(git branch --show-current 2>/dev/null || echo '?')"
	@echo "  Device   : $(DEVICE_NAME) ($(DEVICE_ID))"
	@if xcrun devicectl list devices 2>/dev/null | grep -q "$(DEVICE_ID)"; then \
	  echo "  iPhone   : ✓ connected"; \
	else \
	  echo "  iPhone   : ✗ not connected"; \
	fi
	@echo ""

.PHONY: help
help: ## Show this help
	@echo ""
	@echo "  Story of My Life build pipeline"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
	@echo ""

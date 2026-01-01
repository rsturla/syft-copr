# Makefile for building Syft RPM packages
# Follows the same approach as https://src.fedoraproject.org/rpms/gh
# All builds run in podman containers

SPEC_FILE := syft.spec
NAME := syft
VERSION := $(shell grep '^Version:' $(SPEC_FILE) | awk '{print $$2}')
ARCHIVENAME := $(NAME)-$(VERSION)

# Mock configuration
MOCK_CONFIG ?= fedora-rawhide-x86_64

# Container settings
BUILDER_IMAGE := syft-builder
BUILDER_TAG := latest

.PHONY: all container sources license-update license-verify mock srpm clean distclean help

all: help

help:
	@echo "Syft RPM Build Makefile (containerized)"
	@echo ""
	@echo "Targets:"
	@echo "  container      - Build the builder container image"
	@echo "  sources        - Download source tarball and create vendor archive"
	@echo "  license-update - Update License field in spec from detected licenses"
	@echo "  license-verify - Verify licenses match spec"
	@echo "  srpm           - Build source RPM using mock"
	@echo "  mock           - Build RPM using mock"
	@echo "  clean          - Remove build artifacts"
	@echo "  distclean      - Clean + remove builder container image"
	@echo ""
	@echo "Variables:"
	@echo "  MOCK_CONFIG    - Mock config (default: $(MOCK_CONFIG))"
	@echo ""
	@echo "Package: $(NAME) v$(VERSION)"

# Build builder container if it doesn't exist
container:
	@if ! podman image exists $(BUILDER_IMAGE):$(BUILDER_TAG); then \
		echo "==> Building builder container..."; \
		podman build -t $(BUILDER_IMAGE):$(BUILDER_TAG) -f Containerfile .; \
	else \
		echo "==> Builder container already exists"; \
	fi

# Download source and create vendor archive
sources: container
	@echo "==> Creating source archives..."
	podman run --rm \
		--network=host \
		-v $(CURDIR):/src:Z \
		-w /src \
		$(BUILDER_IMAGE):$(BUILDER_TAG) \
		bash -c '\
			set -e; \
			echo "==> Downloading source tarball..."; \
			spectool -g $(SPEC_FILE); \
			echo "==> Creating vendor archive..."; \
			export GOTOOLCHAIN=auto; \
			go_vendor_archive create --config go-vendor-tools.toml $(SPEC_FILE); \
			echo "==> Sources ready:"; \
			ls -lh $(ARCHIVENAME).tar.gz $(ARCHIVENAME)-vendor.tar.bz2; \
		'

# Update spec license field from detected licenses
license-update: sources
	@echo "==> Updating license field in spec..."
	podman run --rm \
		--network=host \
		-v $(CURDIR):/src:Z \
		-w /src \
		$(BUILDER_IMAGE):$(BUILDER_TAG) \
		bash -c '\
			set -e; \
			go_vendor_license \
				--config go-vendor-tools.toml \
				--path $(SPEC_FILE) \
				report --update-spec; \
			echo "==> License field updated in spec"; \
		'

# Verify licenses match spec
license-verify: sources
	@echo "==> Verifying licenses..."
	podman run --rm \
		--network=host \
		-v $(CURDIR):/src:Z \
		-w /src \
		$(BUILDER_IMAGE):$(BUILDER_TAG) \
		bash -c '\
			set -e; \
			go_vendor_license \
				--config go-vendor-tools.toml \
				--path $(SPEC_FILE) \
				report --verify-spec; \
			echo "==> License verification complete"; \
		'

# Build SRPM using mock
srpm: sources
	@echo "==> Building SRPM with mock..."
	@mkdir -p $(CURDIR)/results
	podman run --rm \
		--privileged \
		--network=host \
		-v $(CURDIR):/src:Z \
		-w /src \
		$(BUILDER_IMAGE):$(BUILDER_TAG) \
		bash -c '\
			set -e; \
			mock -r $(MOCK_CONFIG) --buildsrpm \
				--spec $(SPEC_FILE) \
				--sources . \
				--resultdir ./results; \
			echo "==> SRPM built:"; \
			ls -lh ./results/*.src.rpm; \
		'

# Build RPM using mock
mock: sources
	@echo "==> Building RPM with mock ($(MOCK_CONFIG))..."
	@mkdir -p $(CURDIR)/results
	podman run --rm \
		--privileged \
		--network=host \
		-v $(CURDIR):/src:Z \
		-w /src \
		$(BUILDER_IMAGE):$(BUILDER_TAG) \
		bash -c '\
			set -e; \
			mock -r $(MOCK_CONFIG) \
				--spec $(SPEC_FILE) \
				--sources . \
				--resultdir ./results; \
			echo "==> Build complete!"; \
			ls -lh ./results/*.rpm; \
		'

clean:
	@echo "==> Cleaning..."
	podman run --rm -v $(CURDIR):/src:Z $(BUILDER_IMAGE):$(BUILDER_TAG) \
		rm -f /src/$(NAME)-*.tar.gz /src/$(NAME)-*-vendor.tar.bz2 2>/dev/null || \
		rm -f $(NAME)-*.tar.gz $(NAME)-*-vendor.tar.bz2
	rm -rf ./results
	@echo "==> Clean complete"

distclean: clean
	@echo "==> Removing builder container image..."
	-podman rmi $(BUILDER_IMAGE):$(BUILDER_TAG) 2>/dev/null || true
	@echo "==> Distclean complete"

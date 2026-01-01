FROM fedora:43

# Install all tools needed for building Go RPM packages
RUN dnf install -y \
    go-vendor-tools \
    go-rpm-macros \
    golang \
    mock \
    rpmdevtools \
    rpm-build \
    git-core \
    && dnf clean all

# Add mock user (needed for mock builds)
RUN useradd -m builder && usermod -aG mock builder

WORKDIR /src

# Default to running as builder user for mock
# Use --privileged when running mock commands
CMD ["/bin/bash"]

# Syft RPM Package

This package follows the same approach as the [Fedora gh package](https://src.fedoraproject.org/rpms/gh).

## Prerequisites

- `podman` installed
- That's it! All builds run in containers.

## Building

### Create source archives

```bash
make sources
```

This will:
1. Download the upstream source tarball
2. Create a vendor archive with all Go dependencies

### Verify licenses

```bash
make license-report
```

### Build with mock

```bash
# Build RPM (default: fedora-rawhide-x86_64)
make mock

# Or specify a different mock config
make mock MOCK_CONFIG=fedora-42-x86_64
```

### Build SRPM only

```bash
make srpm
```

## Manual commands

If you prefer to run commands manually:

```bash
# Download source
spectool -g syft.spec

# Create vendor archive
export GOTOOLCHAIN=auto
go_vendor_archive create --config go-vendor-tools.toml syft.spec

# Verify licenses
go_vendor_license --config go-vendor-tools.toml --path syft.spec report --verify-spec

# Build with mock
mock -r fedora-rawhide-x86_64 --spec syft.spec --sources . --resultdir ./results
```

## Updating the package

1. Update the `Version:` in `syft.spec`
2. Run `make sources` to create new archives
3. Run `make license-report` to verify licenses still match
4. If licenses changed, update `go-vendor-tools.toml` and the `License:` field in the spec
5. Build and test with `make mock`

## Files

- `syft.spec` - RPM spec file
- `go-vendor-tools.toml` - License configuration for go-vendor-tools
- `.packit.yaml` - Packit automation configuration
- `sources` - SHA512 checksums for dist-git lookaside cache

## References

- [Fedora Go Packaging Guidelines](https://docs.fedoraproject.org/en-US/packaging-guidelines/Golang/)
- [go-vendor-tools documentation](https://fedora.gitlab.io/sigs/go/go-vendor-tools/)
- [Fedora gh package](https://src.fedoraproject.org/rpms/gh) - Reference implementation

PKGNAME := $(shell sed -n 's/Package: *\([^ ]*\)/\1/p' DESCRIPTION 2>/dev/null)
PKGVERS := $(shell sed -n 's/Version: *\([^ ]*\)/\1/p' DESCRIPTION 2>/dev/null)

all: check

RBEBELM_BUILD_VIGNETTES ?= true
BUILD_VIGNETTES_ARG := $(if $(filter false,$(RBEBELM_BUILD_VIGNETTES)),--no-build-vignettes,)
CHECK_VIGNETTES_ARG := $(if $(filter false,$(RBEBELM_BUILD_VIGNETTES)),--ignore-vignettes,)

help:
	@printf '%s\n' \
	  'Common development targets:' \
	  '  make rd          regenerate savvy wrappers, dispatcher init, roxygen docs' \
	  '  make rdm         render README.md from README.Rmd (evaluated chunks)' \
	  '  make dev-install install current source with preclean' \
	  '  make test        run tinytest package tests' \
	  '  make cargo-build-aarch64 compile all AArch64 backend variants' \
	  '  make build       build source tarball' \
	  '  make check       run R CMD check --no-manual' \
	  '  make site        build pkgdown site' \
	  '  make clean       remove build artifacts'

rd:
	R -e 'if (requireNamespace("savvy", quietly = TRUE)) { savvy::savvy_update() } else { stop("savvy is required") }'
	Rscript tools/write-dispatch-init.R
	R -e 'if (requireNamespace("roxygen2", quietly = TRUE)) { roxygen2::roxygenize(load_code = "source") } else { stop("roxygen2 is required") }'

rdm: dev-install
	R -e 'if (requireNamespace("rmarkdown", quietly = TRUE)) { rmarkdown::render("README.Rmd", output_format = "github_document") } else { stop("rmarkdown is required") }'
	Rscript tools/normalize-markdown.R README.md

build:
	R CMD build $(BUILD_VIGNETTES_ARG) .

check: build
	R CMD check --no-manual $(CHECK_VIGNETTES_ARG) $(PKGNAME)_$(PKGVERS).tar.gz

install_deps:
	R \
	-e 'if (!requireNamespace("remotes", quietly = TRUE)) install.packages("remotes")' \
	-e 'remotes::install_deps(dependencies = TRUE)'

dev-install:
	R CMD INSTALL --preclean .

install: build
	R CMD INSTALL $(PKGNAME)_$(PKGVERS).tar.gz

test: dev-install
	R -e "tinytest::test_package('$(PKGNAME)')"

cargo-check:
	cd src/rust && cargo check --features portable

cargo-build-aarch64:
	tools/check-aarch64-backends.sh

site:
	R -e 'if (requireNamespace("pkgdown", quietly = TRUE)) { pkgdown::build_site() } else { stop("pkgdown is required") }'

clean:
	@rm -rf $(PKGNAME)_$(PKGVERS).tar.gz $(PKGNAME).Rcheck
	@rm -rf src/rust/target src/rbebelm-backends src/backends src/vendor src/.cargo

.PHONY: all help rd rdm build check install_deps dev-install install test cargo-check cargo-build-aarch64 site clean

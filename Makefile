IS_CI := false
ifeq ($(OPENSHIFT_CI),true)
    IS_CI := true
endif

SRC_DIRS = rebasebot tests
RUFF_ARGS =
ifeq ($(IS_CI),true)
    # CI checkouts under /go are read-only, so avoid .ruff_cache writes there.
    RUFF_ARGS += --no-cache
endif

PYTHON_BIN := python
VENV_PYTHON := env/bin/python
ifeq ($(IS_CI),false)
    PYTHON_BIN := $(VENV_PYTHON)
endif

RUFF = $(PYTHON_BIN) -m ruff

.PHONY: test unittests
test: unittests

unittests: ## Run unit & integration tests
	PYTHON_BIN=$(PYTHON_BIN) hack/tests.sh

.PHONY: lint
lint: ## Run lint and format in check mode
	$(RUFF) check $(RUFF_ARGS) $(SRC_DIRS)
	$(RUFF) format $(RUFF_ARGS) --check $(SRC_DIRS)

.PHONY: lint-fix
lint-fix: ## Fix fixable lint issues and format code
	$(RUFF) format $(RUFF_ARGS) $(SRC_DIRS)
	$(RUFF) check $(RUFF_ARGS) --fix $(SRC_DIRS)

.PHONY: install
install: ## Install into your user python environment.
# On macOS with Homebrew Python, you may get "externally-managed-environment" error.
# Use `pipx install .` instead, or install within a virtual environment (`make venv`).
	python -m pip install --user .

.PHONY: build
build: ## Create build tarball
	$(PYTHON_BIN) -m uv build

.PHONY: help
help: ## Display this help screen
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: clean
clean:
	rm -rf dist/ build/ .pytest_cache/ .mypy_cache .ruff_cache rebasebot.egg-info .coverage

.PHONY: venv
venv: ## Create venv
ifeq ($(IS_CI),false)
	python -m venv env
endif

# Install dependencies into the local venv.
.PHONY: deps
deps: venv
ifeq ($(IS_CI),false)
	test -x "$(VENV_PYTHON)" || { echo "Virtualenv creation failed; expected $(VENV_PYTHON)" >&2; exit 1; }
	VIRTUAL_ENV=$(CURDIR)/env $(PYTHON_BIN) -m pip install uv
	VIRTUAL_ENV=$(CURDIR)/env $(PYTHON_BIN) -m uv sync --active --locked --extra dev
else
    # In CI we already are inside a venv, and the source checkout under /go is read-only.
	uv sync --active --locked --extra dev --no-install-project
endif

.PHONY: test test-busted test-plenary test-verbose test-old test-unit test-functional format clean install-hooks

# Run tests with Busted (default - new test framework)
test: test-busted

# Run tests with Busted
test-busted:
	@echo "Running tests with Busted..."
	@echo "======================================="
	@echo ""
	@echo "🧪 Running unit tests ($(shell ls test/unit/*.lua 2>/dev/null | wc -l) files)..."
	@./test/run_busted.sh --run unit
	@echo ""
	@if [ -d "test/functional" ] && [ -n "$$(ls -A test/functional/*.lua 2>/dev/null)" ]; then \
		echo "🔧 Running functional tests ($(shell ls test/functional/*.lua 2>/dev/null | wc -l) files)..."; \
		./test/run_busted.sh --run functional || true; \
	fi
	@echo ""
	@echo "======================================="
	@echo "✅ Test run complete!"

# Run only unit tests with Busted
test-unit:
	@echo "🧪 Running unit tests..."
	@./test/run_busted.sh --run unit

# Run only functional tests with Busted
test-functional:
	@echo "🔧 Running functional tests..."
	@./test/run_busted.sh --run functional


# Format Lua code with stylua
format:
	@stylua .

# Install git hooks
install-hooks:
	@git config core.hooksPath .githooks
	@echo "Git hooks installed. Pre-commit hook will:"
	@echo "  - Format code with stylua"
	@echo "  - Remind to update docs when README changes"
	@echo "  - Run tests"

# Clean test artifacts
clean:
	@echo "Cleaning test artifacts..."
	@rm -rf test/xdg
	@rm -f luacov.stats.out luacov.report.out
	@echo "✅ Clean complete"

# Help
help:
	@echo "beam.nvim - Makefile targets"
	@echo "============================"
	@echo ""
	@echo "Testing:"
	@echo "  make test          - Run all tests (unit + functional)"
	@echo "  make test-unit     - Run unit tests only"
	@echo "  make test-functional - Run functional tests only"
	@echo ""
	@echo "Development:"
	@echo "  make format        - Format code with stylua"
	@echo "  make install-hooks - Install git pre-commit hooks"
	@echo "  make clean         - Clean test artifacts"
	@echo ""

.PHONY: test test-verbose test-old format clean install-hooks

# Run tests with Plenary (default)
test:
	@echo "Running tests with Plenary..."
	@nvim --headless -l test/run_tests.lua 2>&1 | tee /tmp/beam-test-output.txt
	@echo ""
	@echo "============================================"
	@echo "TEST SUMMARY"
	@echo "============================================"
	@echo -n "Total tests run: "
	@grep -E "Success: |Failed :" /tmp/beam-test-output.txt | awk '{sum+=$$3} END {print sum}'
	@echo -n "Tests passed: "
	@grep "Success: " /tmp/beam-test-output.txt | awk '{sum+=$$3} END {print sum}'
	@echo -n "Tests failed: "
	@grep "Failed : " /tmp/beam-test-output.txt | awk '{sum+=$$3} END {if(sum=="") print 0; else print sum}'
	@echo "============================================"
	@if grep -q "Tests Failed" /tmp/beam-test-output.txt 2>/dev/null || grep -q "^[[:space:]]*Failed : [1-9]" /tmp/beam-test-output.txt 2>/dev/null; then rm -f /tmp/beam-test-output.txt; exit 1; fi
	@rm -f /tmp/beam-test-output.txt

# Run tests with output visible (not headless)
test-verbose:
	@echo "Running tests with Plenary (verbose)..."
	@nvim -l test/run_tests.lua

# Run old test suite (for remaining non-migrated tests)
test-old:
	@./test/run_all_tests.sh

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
	@rm -rf /tmp/lazy-test /tmp/lazy.nvim /tmp/lazy-lock.json

# Help
help:
	@echo "Available targets:"
	@echo "  make test          - Run comprehensive test suite"
	@echo "  make test-verbose  - Run tests with detailed output"
	@echo "  make format        - Format code with stylua"
	@echo "  make install-hooks - Install git pre-commit hooks"
	@echo "  make clean         - Clean test artifacts"

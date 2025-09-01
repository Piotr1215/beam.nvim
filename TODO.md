# beam.nvim TODO

## ✅ Completed Today

### Cross-Buffer First-Time Failure Fix
- **Problem**: Cross-buffer operations failed on first attempt, worked on second
- **Root Cause**: `CmdlineLeave` autocmd fired before search register was populated
- **Solution**: Used `CmdlineChanged` to capture search pattern as it's typed
- **Result**: Deterministic, timer-free solution that works reliably

### Telescope Integration (Experimental)
- **Created**: Proof-of-concept Telescope integration for cross-buffer search
- **Files Added**:
  - `lua/beam/telescope_cross_buffer.lua` - Core Telescope picker implementation
  - `lua/beam/telescope_experiment.lua` - Initial experiment (can be removed)
- **Config Added**: `experimental.telescope_integration` flag
- **Current State**: Works for yank operations when cross_buffer=true
- **Benefits**:
  - Visual picker showing all buffers
  - Fuzzy search across buffers
  - Preview of target location
  - Solves Ctrl-G/T navigation limitation

### Test Improvements
- Added test mode (`vim.g.beam_test_mode`) for synchronous test execution
- Fixed all cross-buffer tests to work with new implementation
- Added test summary to Makefile (`make test` now shows totals)
- All 93 tests passing

### Documentation Updates
- Removed `[BROKEN]` tag from cross-buffer feature
- Marked cross-buffer as experimental instead

## 🚀 Future Enhancements

### Telescope Integration Expansion
- [ ] Add delete operator support with Telescope
- [ ] Add change operator support with Telescope
- [ ] Add visual selection support with Telescope
- [ ] Improve picker UI:
  - [ ] Group results by buffer
  - [ ] Add syntax highlighting to preview
  - [ ] Show line numbers more prominently
  - [ ] Add buffer icons/indicators

### Search Provider System
- [ ] Create pluggable search provider API
- [ ] Allow users to register custom search functions
- [ ] Add support for:
  - [ ] fzf-lua as alternative to Telescope
  - [ ] Native vim popup with fuzzy matching
  - [ ] Mini.pick integration
  - [ ] Custom user-defined search functions

### Core Improvements
- [ ] Add proper help documentation for Telescope feature
- [ ] Create `:BeamToggleTelescope` command for easy testing
- [ ] Add health check for Telescope integration
- [ ] Consider making Telescope the default for cross-buffer when available

### Testing
- [ ] Add tests for Telescope integration (mock Telescope calls)
- [ ] Add integration tests with real Telescope
- [ ] Test with various text objects in Telescope mode

### Performance
- [ ] Optimize buffer line collection for large files
- [ ] Add caching for buffer contents in Telescope picker
- [ ] Lazy-load Telescope integration only when needed

## 💡 Ideas from Community

### From User Feedback
- "Opening up an interface that allows the user to choose any kind of search procedure"
- Support for `telescope-fzf-native` for better fuzzy matching
- Consider workflow comparison documentation (beam vs traditional vim)

### Potential Game-Changers
- [ ] Multi-select in Telescope (yank from multiple locations at once)
- [ ] Search history integration (recent beam operations)
- [ ] Smart suggestions based on current context
- [ ] Integration with LSP for semantic search ("yank function named X")

## 📝 Notes

### Architecture Decisions
- Kept Telescope integration optional and experimental
- Maintained backward compatibility completely
- Zero dependencies still (Telescope is optional)
- Fallback gracefully when Telescope not available

### Known Limitations
- Telescope integration only works with cross_buffer enabled
- Currently only yank operator implemented
- No keybinding customization for Telescope mode yet

### Branch Strategy
- Feature branch created for Telescope integration
- Main branch has stable cross-buffer fix
- Can merge Telescope feature after more testing/refinement

## 🐛 Bugs to Fix
- [ ] None currently known! 🎉

## 📚 Documentation Needed
- [ ] Update README with Telescope integration section
- [ ] Add examples of Telescope workflow
- [ ] Create GIF/video showing Telescope in action
- [ ] Document configuration options
- [ ] Add troubleshooting section for Telescope setup

---

*Last Updated: 2025-01-09*
*Cross-buffer is finally working perfectly!*
*Telescope integration is a game-changer!*
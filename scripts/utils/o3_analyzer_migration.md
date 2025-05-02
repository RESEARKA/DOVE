# O3 Code Analyzer: Migration Guide

## Transition to Enhanced Analyzer

The DOVE project has upgraded to an enhanced version of the O3 Code Analyzer that offers more capabilities, better performance, and expanded language support.

### Current Status

- **Original Tool** (DEPRECATED): `/scripts/utils/o3_code_analyzer.py`
- **Enhanced Tool** (RECOMMENDED): `/scripts/utils/o3_code_analyzer_enhanced.py`

### What's New

The enhanced analyzer adds:

1. **Project-wide analysis**: Scan entire directories with pattern exclusions
2. **UI component analysis**: Special focus on accessibility and UX issues
3. **Batch processing**: Analyze multiple files in sequence
4. **Focus area targeting**: Specify exactly what aspects to analyze
5. **Improved reporting**: Consolidated reports and severity filtering

### Migration Steps

1. **Update API Key**:
   - The enhanced tool uses the same API key format in `.env`:
   ```
   O3_API_KEY=sk-your-api-key
   ```

2. **Update Commands**:
   - Change script path from `o3_code_analyzer.py` to `o3_code_analyzer_enhanced.py`
   - Example:
   ```bash
   # OLD
   python3 scripts/utils/o3_code_analyzer.py file contracts/DOVE.sol
   
   # NEW
   python3 scripts/utils/o3_code_analyzer_enhanced.py file contracts/DOVE.sol
   ```

3. **Leverage New Features**:
   - Add focus areas: `--focus "security,performance"`
   - Filter by severity: `--severity "high"`
   - Exclude patterns: `--exclude "tests"`

### Backwards Compatibility

The enhanced tool maintains full compatibility with previous commands:
- `full` - Still works for analyzing the DOVE token implementation
- `file` and `function` - Compatible with previous usage patterns

### Documentation

For full documentation of all new features, see the updated README.md or run:

```bash
python3 scripts/utils/o3_code_analyzer_enhanced.py --help
```

This transition guide was created on: May 2, 2025

# SIMD-Optimized Lexer for ParadoxScript

This document describes the SIMD (Single Instruction, Multiple Data) optimizations applied to the ParadoxScript lexer to improve performance when parsing large game files.

## Overview

The original lexer processed characters one-by-one using standard character classification functions. The SIMD-optimized version processes 16 bytes at a time using vectorized operations, significantly improving throughput for large files.

## Key Optimizations

### 1. Vectorized Whitespace Skipping
- **Before**: Character-by-character `std.ascii.isWhitespace()` calls
- **After**: 16-byte SIMD comparison against space, tab, newline, and carriage return vectors
- **Benefit**: Faster scanning through indented code blocks and comments

### 2. Vectorized Identifier Scanning
- **Before**: Character-by-character `isIdentifierChar()` calls
- **After**: SIMD range checks for a-z, A-Z, 0-9, and underscore
- **Benefit**: Faster processing of long identifier names common in ParadoxScript

### 3. Vectorized Number Scanning
- **Before**: Character-by-character `std.ascii.isDigit()` calls
- **After**: SIMD range check for 0-9
- **Benefit**: Faster processing of numeric values and coordinates

### 4. Vectorized String Content Scanning
- **Before**: Character-by-character search for closing quote
- **After**: SIMD search for quote character across 16 bytes
- **Benefit**: Faster scanning through long string literals

### 5. Vectorized Comment Scanning
- **Before**: Character-by-character search for newline
- **After**: SIMD search for newline character
- **Benefit**: Faster skipping of comment blocks

## Implementation Details

### SIMD Vector Size
- Uses 16-byte vectors (`@Vector(16, u8)`) which work well on most modern processors
- Falls back to scalar processing for remaining bytes at buffer boundaries

### Alignment Handling
- Uses unaligned loads via `@memcpy` to avoid alignment issues with arbitrary input buffers
- This is safer than aligned pointer casts and compatible with any input

### Boolean Vector Operations
- Uses `@select()` for combining boolean masks instead of bitwise operations
- Uses `std.simd.firstTrue()` to find the first non-matching character

## Performance Results

Benchmark on ~2.6MB of ParadoxScript content:
- **Throughput**: ~112 MB/s
- **Processing time**: ~22ms per iteration for 2.6MB
- **Scalability**: Performance scales well with file size due to SIMD bulk operations

## Compatibility

- **Behavior**: Identical to the original lexer - all tests pass
- **API**: No changes to the public interface
- **Error handling**: Same error handling and edge case behavior
- **Platform**: Works on any platform with Zig SIMD support

## Usage

The SIMD optimizations are transparent - simply use the lexer as before:

```zig
var lexer = Lexer.init(source_code);
while (true) {
    const token = lexer.next();
    if (token.tag == .eof) break;
    // Process token...
}
```

## Future Improvements

Potential further optimizations:
1. **Adaptive vector size**: Use larger vectors (32/64 bytes) on processors that support them
2. **Parallel tokenization**: Process multiple chunks simultaneously for very large files
3. **Custom string interning**: SIMD-accelerated string deduplication for identifiers
4. **Branch prediction optimization**: Reorganize hot paths based on ParadoxScript token frequency

## Benchmark

Run the included benchmark with:
```bash
zig run src/lexer_benchmark.zig
```

This processes 1000 copies of a representative ParadoxScript event file to measure throughput. 
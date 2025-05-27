# zck3

A parser for the Crusader Kings III subset of ParadoxScript (also known as Jomini), a scripting language used in Paradox Interactive games, written in Zig.

This project aims to provide a fast and robust implementation of a ParadoxScript lexer and parser, enabling analysis and tooling for CK3 modding and scripting.

# Features

TODO

## TODO
- [x] Lexer
- - [x] Basic syntax
- - [x] Computed values
- - [x] Keywords (effects, triggers, event_scopes, event_targets)
- [ ] Parser
- [ ] AST generation
- [ ] Error reporting
- [ ] CLI tool
- [ ] Documentation
- [ ] LSP

## Implementation Notes
- ParadoxScript grammar contains constructs (like ambiguous block syntax) that cannot be parsed with LL(1) techniques
- The parser implementation uses LR parsing to handle these grammatical structures correctly
- This enables proper distinction between field blocks (`{ key = value }`) and value blocks (`{ r g b }`)

## Usage

```
zig build run
```

## License
MIT

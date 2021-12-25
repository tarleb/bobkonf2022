---
title: Haskell 💖 Lua
author: Albert Krewinkel
---

# What's this about?

## Language overview

|            | Haskell  | Lua         |
|------------+----------+-------------|
| evaluation | lazy     | strict      |
| typing     | static   | dynamic     |
| programs   | compiled | interpreted |
| C API      | ✓        | ✓           |
| GC         | ✓        | ✓           |

## Example FOSS applications

### Haskell

- database web gateway
- window manager
- code and natural language parsing

### Lua

- web API gateway
- window manager
- extending programs

::: notes
#### Haskell examples

PostgREST
:   REST API for PostgreSQL databases

Hasura GraphQL engine
:   GraphQL frontend for databases

XMonad
:   Haskell window manager

ShellCheck
:   Static analyzer / linter for Shell scripts

Semantic
:   Code analyzer

Pandoc
:   Universal document converter

#### Lua examples

Kong
:   Cloud-native API gateway

Awesome
:   Lua window manager

neovim
:   Lua-focused rewrite of vim

hammerspoon
:   making OS X scriptable
:::

# FFI

## Foreign Function Interface

- Use programs written in a different language
- Must support the relevant types
- Bridges the runtime

## Function imports

## Safety


# C Types

## Stable Pointer

## Free stable pointer

## `setjmp` & `longjmp`

# In action

## deftype

## pushhaskellfunction

## pushDocumentedFunction

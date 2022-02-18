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

## Use-cases

### Haskell

- web gateway
- window manager
- code and natural language parsing

### Lua

- web gateway
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

``` c
void lua_pushnumber (lua_State *L, lua_Number n);
```

Import
``` haskell
{-# LANGUAGE CApiFFI #-}
foreign import capi "lua.h lua_pushnumber"
  lua_pushnumber :: Lua.State -> Lua.Number -> IO ()
```

## Safety

- Callbacks into Haskell are allowed.
- Requires some runtime investment.
- Can be avoided by using `unsafe`.

``` haskell
-- Improves performance by a third
--                  vvvvvv
foreign import capi unsafe "lua.h lua_pushnumber"
  lua_pushnumber :: Lua.State -> Lua.Number -> IO ()
```

## Speed
https://github.com/dyu/ffi-overhead


# C Types

## Pointers

- memory address
- In Haskell: `Foreign.Ptr`
- Typed: `Ptr a` is the address of an `a`

## Stable Pointer

- GC may relocate objects
- Create stable pointer with `Foreign.StablePtr`

``` haskell
xptr <- newStablePtr x
-- ...
freeStablePtr xptr
```

## Free stable pointer

## `setjmp` & `longjmp`

# In action

## deftype

## pushhaskellfunction

## pushDocumentedFunction


## 🧑‍💼🏢🧑‍💻

RStudio

::: notes
RStudio is a large, successful software company. They are rebuilding a popular
product, R Markdown, and base it on pandoc's Lua interface.
:::


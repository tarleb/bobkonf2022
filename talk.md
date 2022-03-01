---
title: Haskell 💖 Lua
author: Albert Krewinkel
subtitle: Come together over FFI
---

# What's this about?

## whoami

- HsLua
- Pandoc contrib
- Scientific publishing

::: notes
- HsLua was created by Gracjan Polak in 2007; I took it over from Ömer
  Sinan Ağacan in 2016.
- In my 8th year of contributing to pandoc.
- On a quest to improve scientific writing and publishing.

## Language overview

::: columns
::::: column
### Haskell

- lazy evaluation
- static typing
- compiled
:::::

::::: column
### Lua

- strict evaluation
- dynamic typing
- interpreted
:::::
:::

## Use-cases

::: columns
::::: column
### Haskell

- web gateway

  (PostgREST, Hasura)

- window manager

  (XMonad)

:::::

::::: column
### Lua

- web gateway

  (Kong)

- window manager

  (Awesome)
:::::
:::

::: notes
#### Haskell examples

PostgREST
:   REST API for PostgreSQL databases

Hasura GraphQL engine
:   GraphQL frontend for databases

XMonad
:   Haskell window manager

#### Lua examples

Kong
:   Cloud-native API gateway

Awesome
:   Lua window manager
:::

## Use-cases

::: columns
::::: column
### Haskell

Complex systems
:::::

::::: column
### Lua

Scriptable systems
:::::
:::

::: notes
"Scriptable" here means that a program can be extended through short
Lua scripts.

### Haskell
ShellCheck
:   Static analyzer / linter for Shell scripts

Semantic
:   Code analyzer

Pandoc
:   Universal document converter

### Lua
neovim
:   Lua-focused rewrite of vim

hammerspoon
:   making OS X scriptable
:::

## Example: pandoc

```haskell
data Inline
  = Str Text           -- ^ Text (string)
  | Emph [Inline]      -- ^ Emphasized text
  | SmallCaps [Inline] -- ^ Small caps text
  -- ⋮
```

| Markdown    | Pandoc AST                  |
|:-----------:|:----------------------------|
|  `*Hello*`  | `Emph [Str "Hello"]`        |
|  `_Hello_`  | `Emph [Str "Hello"]`        |
| `_*Hello*_` | `Emph [Emph [Str "Hello"]]` |
|      ?      | `SmallCaps [Str "Hello"]]`  |

::: notes

Pandoc is a universal document converter, parses documents into an
internal AST.

Markdown allows to write emphasized text either as `_hello_` or
`*hello*`, so using both gives nested Emph.

:::

## Pandoc Lua filter

``` lua
function Emph (em)
  local nested = #em.content == 1 and em.content[1]
  if nested and nested.t == 'Emph' then
    return pandoc.SmallCaps(nested.content)
  end
end
```

In action

```
 % pandoc --to=latex <<< '_*Hello*_'
=> \emph{\emph{Hello}}

 % pandoc --lua-filter=smallcaps.lua --to=latex <<< '_*Hello*_'
=> \textsc{Hello}
```

## Language overview

|          | Haskell  | Lua         |
|----------|----------|-------------|
| typing   | static   | dynamic     |
| programs | compiled | interpreted |
| FP       | ✓        | ✓           |
| GC       | ✓        | ✓           |
| C API    | ✓        | ✓           |

::: notes

The languages are different in many key aspects, but they share some
common properties.

FP
:   Haskell is a pure functional programming language, while Lua is
    imperative with good functional programming support (functions are
    first-class citizens).

GC
:   bit of a problem, because we must be careful that the GCs don't get
    in each others way.

C API
:   Both have excellent C interoperability; we can use that to make them
    work together.
:::

# FFI

## Foreign Function Interface

- Use programs written in a different language
- Must support the relevant types
- Builds bridges from the runtime system.

## Function imports

C header
``` c
void (lua_pushboolean) (lua_State *L, int b);
```

Import
``` haskell
foreign import capi "lua.h lua_pushboolean"
  lua_pushboolean :: Ptr () -> CInt -> IO ()
```

::: notes

Importing is straight-forward; the C function becomes usable as a
Haskell function.

:::

## Types

Simple in C

``` c
int (lua_setiuservalue) (lua_State *L, int idx, int n);
```

Expressive in Haskell

``` haskell
newtype LuaBool    = LuaBool CInt    deriving (Storable)
newtype StackIndex = StackIndex CInt deriving (Storable, Num)

foreign import capi "lua.h lua_setiuservalue"
  lua_setiuservalue :: Lua.State -> StackIndex -> CInt
                    -> IO LuaBool
```

::: notes
Types in C are nice and simple, while types in Haskell are expressive
and fine-grained. Conversions work well, types must just be instances of
`Storable`.
:::

## package: lua

Basic bindings to Lua

``` haskell
getAge :: Lua.State -> IO Lua.Integer
getAge l = do
  withCString "age" $
    lua_getfield l LUA_REGISTRYINDEX
  result <- lua_tointegerx l (-1) nullPtr
  lua_pop l 1
  pure result
```

::: notes
The `lua` package provides bindings to all basic Lua functions.
Writing C in Haskell is possible, but not pretty.
:::

## hslua: Familiar Haskell feeling

``` haskell
-- | Get name field from registry table.
getAge :: Lua (Maybe Integer)
getAge = do
  getfield registryindex "age"
  tointeger top <* pop 1
```

::: notes
Nicer types, dedicated `Lua` monad.
:::

## Reader monad

Lua state as first argument

``` haskell
lua_getfield    :: State -> ...
lua_pushboolean :: State -> ...
```

``` haskell
newtype Lua a = Lua { unLua :: ReaderT State IO a }
  deriving (Monad, MonadIO, MonadReader State)

main = run $ do
  age <- getAge
  ...
```

::: notes
Lua's C API functions typically take the Lua state as the first
argument. This is the pattern of the Reader monad, which can be used to
'hide' the Lua state so it doesn't have to be dragged along manually.

The `run` function just opens and closes a Lua state.
:::


# Data exchange

## Stack

```
       <----???--- Just (23 % 5) ::
,----------.       Maybe (Ratio Int)
|     5    |
+----------+
|   true   |
+----------+
| "banana" |
```

::: notes
The C API makes it easy to deal with simple values like numbers,
booleans, and strings. However, how would be put a Haskell value on the
stack?
:::

## Userdata

- Wrapper for arbitrary data.
- Behavior in Lua can be mended freely.
- Frequently used with pointers.
- But pointers don't work well with GC.

```
,---------.
|  ??? ---|----> data
`---------'
```

::: notes
- Garbage collection makes pointers difficult, because objects will
  often be moved around, breaking any pointer.
:::

## Stable Pointer

- Create stable pointer with `Foreign.StablePtr`
- Not a pointer in the C sense

``` haskell
xptr <- newStablePtr x
-- ...
x' <- deRefStablePtr xptr
freeStablePtr xptr
```

## Pointers in userdata

```
,------------.
| StablePtr -|----> Haskell value
`------------'
```
``` haskell
  xPtr <- newStablePtr x
  udPtr <- lua_newuserdata l (fromIntegral $ sizeOf xPtr)
  poke (castPtr udPtr) xPtr
  -- ??? freeStablePtr ???
```

## Define behavior in Haskell

``` c
  HsStablePtr *userdata = lua_touserdata(L, 1);
  if (userdata) {
    hs_free_stable_ptr(*userdata);
  }
```

# In action

## Types

``` haskell
typeRational = deftype "Rational"
  [ operation Tostring $ lambda
      ### liftPure show
      <#> parameter (peekUD typeRational) "rational" "r"
      =#> functionResult pushString "string" "string representation"
  ]
  [ property "numerator" "numerator of the ratio in reduced form"
      (pushIntegral, numerator)
      (peekIntegral, \r n -> n % denominator r)
  ]
```

## Functions

``` haskell
registerRational = do
  pushDocumentedFunction $
   defun "Rational"
      ### liftPure2 (%)
      <*> parameter peekIntegral "integer" "numerator"
      <*> parameter peekIntegral "integer" "denominator"
      =#> functionResult (pushUD typeRational)
  setglobal "Rational"
```

## Tests

``` lua
return {
  group 'examples'  {
    test('multiplication', function()
      assert.are_equal(6, 2 * 3)
    end),
    test('empty var is nil', function ()
      assert.is_nil(var)
    end)
  }
}
```

## Tasty integration
``` haskell
main = do
  luaTest <- withCurrentDirectory "test" . run $ do
    translateResultsFromFile "example-tests.lua"
  defaultMain . testGroup "Haskell and Lua tests" $
    [ luaTest {- more tasty tests go here -} ]
```

```
  test/example-tests.lua
    constructor
      has type `userdata`:       OK
      accepts list of integers:  OK
    comparison
      equality:                  OK
```

::: notes
Tasty is a popular Haskell testing framework. Lua tests can be
integrated into a Tasty test-suite.
:::


## 🧑‍💼🏢🧑‍💻

RStudio

::: notes
RStudio is a large, successful software company. They are rebuilding a popular
product, R Markdown, and base it on pandoc's Lua interface.
:::


# Thanks

## Summary

- Haskell and Lua are both excellent languages
- Together they are even stronger
- Integrating Lua into Haskell apps is easy
- HsLua is a ready-to-use framework


# Appendix

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

## Free stable pointer

## `setjmp` & `longjmp`

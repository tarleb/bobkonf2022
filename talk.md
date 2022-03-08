---
title: Haskell 💖 Lua
author: Albert Krewinkel
subtitle: Come together over FFI
---

# What's this about?

## whoami

- Scientific publishing
- Pandoc contrib
- HsLua

::: notes
- In my 8th year of contributing to pandoc.
- On a quest to improve scientific writing and publishing.
- HsLua was created by Gracjan Polak in 2007; I took it over from Ömer
  Sinan Ağacan in 2016.

- When I took it over: 680 loc
- Now: ~3600 loc
:::

## Language overview

::: columns
::::: column
### Haskell

- static typing
- compiled
- lazy evaluation
:::::

::::: column
### Lua

- dynamic typing
- interpreted
- strict evaluation
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

::: {style="font-size:0.75em;"}

| Markdown    | Pandoc AST                  |
|:-----------:|:----------------------------|
|  `*Hello*`  | `Emph [Str "Hello"]`        |
|  `_Hello_`  | `Emph [Str "Hello"]`        |
| `_*Hello*_` | `Emph [Emph [Str "Hello"]]` |
|      ?      | `SmallCaps [Str "Hello"]]`  |

:::

::: notes

Pandoc is a universal document converter, parses documents into an
internal AST.

Markdown allows to write emphasized text either as `_hello_` or
`*hello*`, so using both gives nested Emph.

:::

## Pandoc Lua filter

``` lua
function Emph (em)
  local nested = em.content[1]
  if nested and nested.t == 'Emph' then
    return pandoc.SmallCaps(nested.content)
  end
end
```

In action

```
% echo '_*Hello*_' | pandoc --to=latex
⇒ \emph{\emph{Hello}}

% echo '_*Hello*_' | pandoc --to=latex --lua-filter=sc.lua
⇒ \textsc{Hello}
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

- Connects programs written in different languages
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
-- | Retrieve content of field \"age\" from the registry.
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


# Data

## Stack

```
        ,----------.
        |  arg 3   |
        +----------+
        |  arg 2   |
        +----------+
        |  arg 1   |
        +----------+                  ,----------.
        | function |    call 3 1      | result 1 |
        +----------+   ===========>   +----------+
        |          |                  |          |
        |  stack   |                  |  stack   |
        |          |                  |          |
```

::: notes
Function calls work by pushing a function and its arguments to the
stack. The function is then called with the given number of arguments,
and the results are pushed back to the stack.
:::

## Marshal

```
       <----???--- Emph [Str "a"] :: Inline
,----------.
|     5    |
+----------+
|   true   |
+----------+
| "banana" |
```

::: notes
The C API makes it easy to deal with simple values like numbers,
booleans, and strings. However, how would we put a Haskell value on the
stack?
:::

## Lua tables

``` haskell
pushInline x = do
  newtable
  case x of
    Str txt -> pushText txt *> setfield (nth 2) "text"
    Emph xs -> pushList pushInline xs *>
               setfield (nth 2) "content"
    -- ...
```

`Str "a"` becomes

``` lua
x = {text = 'a'}
print(x.text) -- prints: a
```

## Metatables

Metatables define object behavior.

``` lua
local mt = {
  __add   = function (a, b) return {a, b} end,
  __index = function (t, k) return 42 end,
  __gc    = function () print('collected') end,
}

local x = setmetatable({1}, mt)
local nope  = {1} + 1 -- ⇒ ERROR!
local tuple = x + 2   -- tuple == {x, 2}
print(x[1], x.hello)  -- prints: 1, 42
```

::: notes
Metatables control how an object is used with operators, how it is
printed, iterated, and indexed.

This also allows for object-oriented programming; metatables can be
treated as defining "classes".

Similar to special methods in Python.
:::

## Table values

- Straight-forward
- Simple
- Strict

::: notes

Tables are Lua's primary data structure, using them is very natural.
This is what we used for the initial version of pandoc Lua filters.

However, it also requires strict evaluation, which is not what we want
when dealing with large (possibly infinite) objects.
:::

## Userdata

- Wrapper for arbitrary data.
- Metatables define behavior.
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

::: notes
Types of the invoked functions:

- `newStablePtr    :: a -> IO (StablePtr a)`
- `deRefStablePtr  :: StablePtr a -> IO a`
- `freeStablePtr   :: StablePtr a -> IO ()`
:::

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

::: notes
Line-by-line

- create a new (stable) pointer
- create a new userdata object on the stack that can fit a stable
  pointer.
- Store the stable pointer in the userdata.
- When do we free it?

Types of the invoked functions:

- `newStablePtr    :: a -> IO (StablePtr a)`
- `lua_newuserdata :: State -> CSize -> IO (Ptr ())`
- `poke            :: Storable a => Ptr a -> a -> IO ()`
:::

## Free pointer

Set `__gc` metamethod on userdata.

``` c
#include <HsFFI.h>

static int hslua_userdata_gc(lua_State *L) {
  HsStablePtr *userdata = lua_touserdata(L, 1);
  if (userdata)
    hs_free_stable_ptr(*userdata);
  return 0;
}
```

::: notes
Userdata values are freed via a C function (for performance).
`HsFFI.h` defines the types required for that.

- `void	*(lua_touserdata) (lua_State *L, int idx);`
- `void hs_free_stable_ptr (HsStablePtr)`
:::

# In action

::: notes

We've seen that Haskell brings all the features necessary to work with Lua.
This may all sound neat, but you may be asking "how am I supposed to use
that?"

The goal is to give pandoc contributors access to the Lua subsystem's
workings with relative ease.

:::

## Types

``` haskell
-- | A table row.
data Row = Row Attr [Cell]

typeRow = deftype "Row" []
  [ property "cells" "row cells"
      (pushList pushCell, \(Row _ cells) -> cells)
      (peekList peekCell, \(Row attr _) cells ->
                             Row attr cells)
  ]
```

``` lua
-- print first cell in row
print(row.cells[1])
```

## Functions

``` haskell
mkRow = defun "Row"
  ### liftPure2 Row -- lift a pure Haskell function to Lua
  <#> udparam typeAttr "attr" "cell attributes"
  <#> parameter (peekList peekCell) "{Cell,...}"
        "cells" "row cells"
  =#> udResult typeRow "new Row object"

registerDocumentedFunction mkRow
```

In Lua:

``` lua
empty_row = Row(Attr(), {})
```

::: notes
Function `liftPure2` is defined as

``` haskell
liftPure2 :: (a -> b -> c)
          -> (a -> b -> LuaE e c)
liftPure2 f !a !b = return $! f a b
```

We don't want lazy IO, hence the extra strictness.
:::

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

## Property tests
``` lua
    test('property test with integers',
      forall(
        arbitrary.integer,
        function (i)
          return type(i) == 'number' and math.floor(i) == i
        end
      )
    ),
```

# 🧑‍💻🏢🧑‍💼

## pandoc

![Pandoc-related projects written in Lua on
GitHub](images/pandoc-lua-on-github.png)


## quarto

![Scientific and technical publishing
system](images/icon-quarto.svg){width="3em"}

::: notes
RStudio is a large, successful software company. They are rebuilding a popular
product, R Markdown, and base it on pandoc's Lua interface.
:::


# End

## Thanks

HsLua
:   [hslua.org](https://hslua.org)

Code
:   [github.com/hslua/hslua](https://github.com/hslua/hslua)

Languages
:   [lua.org](https://lua.org), [haskell.org](https://haskell.org)

pandoc Lua filters
:   [pandoc.org/lua-filters](https://pandoc.org/lua-filters.html)

Quarto
:   [quarto.org](https://quarto.org)

::: notes

- Haskell and Lua are both excellent languages
- Together they are even stronger
- Integrating Lua into Haskell apps is easy
- HsLua is a ready-to-use framework

:::


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

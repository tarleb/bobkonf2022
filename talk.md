---
title: Haskell 💖 Lua
author: Albert Krewinkel
subtitle: Come together over FFI
---

# What's this about?

## Use-cases

::: columns
::::: column
### Haskell

- web gateway
- window manager
- code and natural language parsing
:::::

::::: column
### Lua

- web gateway
- window manager
- extending programs
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

## Use-cases

::: columns
::::: column
### Haskell

Complex systems
:::::

::::: column
### Lua

Extensible systems
:::::
:::
## Language overview

|            | Haskell  | Lua         |
|------------+----------+-------------|
| evaluation | lazy     | strict      |
| typing     | static   | dynamic     |
| programs   | compiled | interpreted |
| GC         | ✓        | ✓           |
| C API      | ✓        | ✓           |

# FFI

## Foreign Function Interface

- Use programs written in a different language
- Must support the relevant types
- Bridges the runtime

## Function imports

``` c
void (lua_pushboolean) (lua_State *L, int b);
```



Import
``` haskell
foreign import capi "lua.h lua_pushboolean"
  lua_pushboolean :: Ptr () -> CInt -> IO ()
```

## Simple types in C

``` c
int (lua_setiuservalue) (lua_State *L, int idx, int n);
```

## Expressive types in Haskell

``` haskell
newtype LuaBool    = LuaBool CInt    deriving Storable
newtype StackIndex = StackIndex CInt deriving Storable

foreign import capi "lua.h lua_setiuservalue"
  lua_setiuservalue :: Lua.State -> StackIndex -> CInt
                    -> IO LuaBool
```

## package: lua

Basic bindings to Lua

``` haskell
getAge :: Lua.State -> IO Integer
getAge l = do
  withCString "age" $
    lua_getfield l LUA_REGISTRYINDEX
  result <- lua_tointegerx l (-1) nullPtr
  lua_pop l 1
  pure result
```

## Haskell feeling

``` haskell
-- | Get name field from registry table.
getAge :: Lua (Maybe Integer)
getAge = do
  getfield registryindex "age"
  tointeger top <* pop 1
```

## Reader monad

``` haskell
newtype Lua a = Lua { unLua :: ReaderT State IO a }
  deriving (Monad, MonadIO, MonadReader State)
```

## package: hslua-core



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

## Userdata

- Wrapper for arbitrary data.
- Behavior in Lua can be mended freely.
- Frequently used with pointers.

```
,---------.
|  ??? ---|----> data
`---------'
```

## Pointers

- memory address
- In Haskell: `Foreign.Ptr`
- GC may relocate objects

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

## Define behavior in Haskell





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

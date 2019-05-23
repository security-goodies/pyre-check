(* Copyright (c) 2016-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree. *)

open Core
open OUnit2

open Ast
open Plugin

open Test


let test_transform_ast _ =
  let assert_expand ?(qualifier = "qualifier") source expected =
    let handle = File.Handle.create qualifier in
    let parse = parse ~qualifier:(Source.qualifier ~handle) in
    assert_source_equal
      (parse expected)
      (NamedTuples.transform_ast (parse source))
  in
  assert_expand
    {|
      $local_qualifier$T = typing.NamedTuple('T')
    |}
    {|
      class qualifier.T(typing.NamedTuple):
        def qualifier.T.__init__(self): ...
        qualifier.T._fields: typing.Tuple[()] = ()
    |};
  assert_expand
    {|
      T = collections.namedtuple('T', ['a'])
    |}
    {|
      class T(typing.NamedTuple):
        def T.__init__(self, $parameter$a: typing.Any): ...
        T._fields: typing.Tuple[str] = ('a',)
        T.a: typing.Any
    |};
  assert_expand
    {|
      T = typing.NamedTuple('T', ['one', 'two'])
    |}
    {|
      class T(typing.NamedTuple):
        def T.__init__(self, $parameter$one: typing.Any, $parameter$two: typing.Any): ...
        T._fields: typing.Tuple[str, str] = ('one', 'two')
        T.one: typing.Any
        T.two: typing.Any
    |};
  assert_expand
    {|
      T = typing.NamedTuple('T', [('one', int), ('two', str)])
    |}
    {|
      class T(typing.NamedTuple):
        def T.__init__(self, $parameter$one: int, $parameter$two: str): ...
        T._fields: typing.Tuple[str, str] = ('one', 'two')
        T.one: int
        T.two: str
    |};
  assert_expand
    {|
      T = collections.namedtuple('T', 'a b c')
    |}
    {|
      class T(typing.NamedTuple):
        def T.__init__(
          self,
          $parameter$a: typing.Any,
          $parameter$b: typing.Any,
          $parameter$c: typing.Any): ...
        T._fields: typing.Tuple[str, str, str] = ('a', 'b', 'c')
        T.a: typing.Any
        T.b: typing.Any
        T.c: typing.Any
    |};

  assert_expand
    {|
      class Foo(Bar, collections.namedtuple('T', ['one', 'two'])):
        Foo.three: int = 1
    |}
    {|
      class Foo(Bar, typing.NamedTuple):
        def Foo.__init__(self, $parameter$one: typing.Any, $parameter$two: typing.Any): ...
        Foo._fields: typing.Tuple[str, str] = ('one', 'two')
        Foo.one: typing.Any
        Foo.two: typing.Any
        Foo.three: int = 1
    |};

  assert_expand
    {|
      class Foo(typing.NamedTuple):
        Foo.a: int
        Foo.b: str
        Foo.c: int = 3
    |}
    {|
      class Foo(typing.NamedTuple):
        def Foo.__init__(self, $parameter$a: int, $parameter$b: str, $parameter$c: int = 3): ...
        Foo._fields: typing.Tuple[str, str, str] = ('a', 'b', 'c')
        Foo.a: int
        Foo.b: str
        Foo.c: int = 3
    |};

  assert_expand
    {|
      class Foo(collections.namedtuple("PatchDocument", ("op", "path", "value", "ts", "lazy"))):
        pass
    |}
    {|
      class Foo(typing.NamedTuple):
         def Foo.__init__(
           self,
           $parameter$op: typing.Any,
           $parameter$path: typing.Any,
           $parameter$value: typing.Any,
           $parameter$ts: typing.Any,
           $parameter$lazy: typing.Any):
           ...
         Foo._fields: typing.Tuple[str, str, str, str, str] = ('op', 'path', 'value', 'ts', 'lazy')
         Foo.op: typing.Any
         Foo.path: typing.Any
         Foo.value: typing.Any
         Foo.ts: typing.Any
         Foo.lazy: typing.Any
         pass
    |};

  assert_expand
    {|
      class Foo:
        T = collections.namedtuple('T', ("a", "b"))
    |}
    {|
      class Foo:
        class T(typing.NamedTuple):
          def T.__init__(self, $parameter$a: typing.Any, $parameter$b: typing.Any): ...
          T._fields: typing.Tuple[str, str] = ('a', 'b')
          T.a: typing.Any
          T.b: typing.Any
    |};

  assert_expand
    {|
      def foo():
        T = typing.NamedTuple('T')
    |}
    {|
      def foo():
        class T(typing.NamedTuple):
          def T.__init__(self): ...
          T._fields: typing.Tuple[()] = ()
    |};

  (* TODO (T42893621): properly handle this case *)
  assert_expand
    {|
      class Foo:
        def __init__($parameter$self):
          $parameter$self.t = typing.NamedTuple('T', 'a')
    |}
    {|
      class Foo:
        def __init__($parameter$self):
          $parameter$self.t = typing.NamedTuple('T', 'a')
    |}


let () =
  "plugin_named_tuples">:::[
    "transform_ast">::test_transform_ast;
  ]
  |> Test.run

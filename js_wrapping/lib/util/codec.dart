// Copyright (c) 2015, Alexandre Ardhuin. All rights reserved. Use of this
// source code is governed by a BSD-style license that can be found in the
// LICENSE file.

library js_wrapping.util.codec;

import 'dart:convert';
export 'dart:convert' show Codec;

import 'package:js_wrapping/js_wrapping.dart';

/// Determines a true or false value for a given input.
typedef bool Predicate<T>(T o);

/// Provides a [T] object from [S].
typedef T Factory<S, T>(S o);

/// A [Codec] that provides additionnal functions to ensure the encoded/decoded
/// values are supported.
class ConditionalCodec<S, T> extends Codec<S, T> {
  final Converter<S, T> encoder;
  final Converter<T, S> decoder;
  final Predicate acceptEncodedValue;
  final Predicate acceptDecodedValue;

  ConditionalCodec._(this.encoder, this.decoder, this.acceptEncodedValue,
      this.acceptDecodedValue);
  ConditionalCodec(Converter<S, T> encoder, Converter<T, S> decoder,
      {Predicate acceptEncodedValue, Predicate acceptDecodedValue})
      : this._(encoder, decoder,
          acceptEncodedValue != null ? acceptEncodedValue : (o) => o is T,
          acceptDecodedValue != null ? acceptDecodedValue : (o) => o is S);
  ConditionalCodec.fromFactories(Factory<S, T> encode, Factory<T, S> decode,
      {Predicate acceptEncodedValue, Predicate acceptDecodedValue})
      : this(new _Converter<S, T>(encode), new _Converter<T, S>(decode),
          acceptEncodedValue: acceptEncodedValue,
          acceptDecodedValue: acceptDecodedValue);
}

class _Converter<S, T> extends Converter<S, T> {
  final Factory<S, T> _factory;

  _Converter(this._factory);

  @override
  T convert(S input) => input == null ? null : _factory(input);
}

/// A [ConditionalCodec] that accepts only [T] values and does not do any
/// transformations.
class IdentityCodec<T> extends ConditionalCodec<T, T> {
  IdentityCodec() : super.fromFactories((T o) => o, (T o) => o);
}

/// A [ConditionalCodec] that accepts any values and apply [asJs] for encoding.
class DynamicCodec extends ConditionalCodec {
  DynamicCodec() : super.fromFactories(asJs, (o) => o,
          acceptEncodedValue: (o) => true, acceptDecodedValue: (o) => true);
}

/// A [ConditionalCodec] that handles a given kind of [JsInterface].
class JsInterfaceCodec<T extends JsInterface>
    extends ConditionalCodec<T, JsObject> {
  JsInterfaceCodec(Factory<JsObject, T> decode,
      [Predicate<JsObject> acceptEncodedValue])
      : super.fromFactories((T o) => asJsObject(o), decode,
          acceptEncodedValue: acceptEncodedValue);
}

/// A [ConditionalCodec] that handles [List].
class JsListCodec<T> extends ConditionalCodec<List<T>, JsArray> {
  JsListCodec(ConditionalCodec<T, dynamic> codec) : super.fromFactories(
          (List<T> o) => o is JsArray
              ? o as JsArray
              : o is JsInterface
                  ? asJsObject(o as JsInterface)
                  : asJsObject(new JsList(codec)..addAll(o)),
          (o) => new JsList.created(o, codec));
}

/// A [ConditionalCodec] that handles [Map]<[String], dynamic>
class JsObjectAsMapCodec<T> extends ConditionalCodec<Map<String, T>, JsObject> {
  JsObjectAsMapCodec(ConditionalCodec<T, dynamic> codec) : super.fromFactories(
          (Map<String, T> o) => o is JsObject
              ? o as JsObject
              : o is JsInterface
                  ? asJsObject(o as JsInterface)
                  : asJsObject(new JsObjectAsMap(codec)..addAll(o)),
          (o) => new JsObjectAsMap.created(o, codec));
}

/// A [ConditionalCodec] used for union types.
class BiMapCodec<S, T> extends ConditionalCodec<S, T> {
  BiMapCodec._(Map<S, T> encode, Map<T, S> decode)
      : super.fromFactories((S o) => encode[o], (T o) => decode[o]);
  BiMapCodec(Map<S, T> map)
      : this._(map, new Map<T, S>.fromIterables(map.values, map.keys));
}

/// A [ConditionalCodec] that handles function.
class FunctionCodec<T extends Function>
    extends ConditionalCodec<T, dynamic /*JsFunction|Function*/ > {
  FunctionCodec(Factory<T, dynamic /*JsFunction|Function*/ > encode,
      Factory<JsFunction, T> decode)
      : super.fromFactories(encode, decode,
          acceptEncodedValue: (o) => o is JsFunction);
}

class ChainedCodec extends ConditionalCodec {
  final List<ConditionalCodec> _codecs;

  ChainedCodec() : this._(<ConditionalCodec>[]);
  ChainedCodec._(List<ConditionalCodec> _codecs)
      : _codecs = _codecs,
        super(new _ChainedConverter(_codecs, true),
            new _ChainedConverter(_codecs, false));

  void add(ConditionalCodec codec) {
    _codecs.add(codec);
  }
}

class _ChainedConverter extends Converter {
  final List<ConditionalCodec> _codecs;
  final bool encoder;

  _ChainedConverter(this._codecs, this.encoder);

  @override
  convert(input) {
    for (final codec in _codecs) {
      var value;
      if (encoder && codec.acceptDecodedValue(input)) {
        value = codec.encode(input);
      }
      if (!encoder && codec.acceptEncodedValue(input)) {
        value = codec.decode(input);
      }
      if (value != null) {
        return value;
      }
    }
    return input;
  }
}

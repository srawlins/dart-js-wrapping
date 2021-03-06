// Copyright (c) 2015, Alexandre Ardhuin. All rights reserved. Use of this
// source code is governed by a BSD-style license that can be found in the
// LICENSE file.

library js_wrapping.adapter.object_as_map;

import 'dart:collection' show Maps, MapMixin;
import 'dart:convert';
import 'dart:js';

import 'package:js_wrapping/js_wrapping.dart' show JsInterface;

import '../src/codec_util.dart';

final _obj = context['Object'] as JsFunction;

/// A [Map] interface wrapper for [JsObject]s.
///
/// Values returned from this map are automatically converted to JavaScript with
/// the [Codec] provided when building the instance.
///
/// Keys must be [String] because they are used as JavaScript property names.
/// The key `__proto__` is disallowed.
class JsObjectAsMap<V> extends JsInterface with MapMixin<String, V> {
  final JsObject _o;
  final Codec<V, dynamic> _codec;

  /// Creates an instance backed by a new JavaScript object whose prototype is
  /// Object.
  JsObjectAsMap(Codec<V, dynamic> codec)
      : this.created(new JsObject(_obj), codec);

  /// Creates an instance backed by the JavaScript object [o].
  JsObjectAsMap.created(JsObject o, Codec<V, dynamic> codec)
      : _o = o,
        _codec =
            codec != null ? codec : const IdentityCodec() as Codec<V, dynamic>,
        super.created(o);

  void _checkKey(String key) {
    if (key == '__proto__') {
      throw new ArgumentError("'__proto__' is disallowed as a key");
    }
  }

  @override
  V operator [](Object key) => _codec.decode(_o[key]);

  @override
  void operator []=(String key, V value) {
    _checkKey(key);
    _o[key] = _codec.encode(value);
  }

  @override
  V remove(Object key) {
    final value = this[key];
    _o.deleteProperty(key as String);
    return value;
  }

  @override
  Iterable<String> get keys =>
      _obj.callMethod('keys', [_o]) as Iterable<String>;

  @override
  bool containsKey(Object key) => _o.hasProperty(key as String);

  @override
  V putIfAbsent(String key, V ifAbsent()) {
    _checkKey(key);
    return Maps.putIfAbsent(this, key, ifAbsent) as V;
  }

  @override
  void addAll(Map<String, V> other) {
    if (other != null) {
      other.forEach((k, v) => this[k] = v);
    }
  }

  @override
  void clear() => Maps.clear(this);
}

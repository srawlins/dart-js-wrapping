// Copyright (c) 2016, Alexandre Ardhuin. All rights reserved. Use of this
// source code is governed by a BSD-style license that can be found in the
// LICENSE file.

library js_wrapping_generator.tool.phases;

import 'package:build_runner/build_runner.dart';
import 'package:js_wrapping_generator/js_interface_generator.dart';
import 'package:source_gen/source_gen.dart';

final List<BuildAction> phases = <BuildAction>[
  new BuildAction(
    new PartBuilder([new JsInterfaceGenerator()]),
    'js_wrapping_generator',
    inputs: const [
      'example/**/*.dart',
      'example/*.dart',
      'test/*.dart',
    ],
  )
];

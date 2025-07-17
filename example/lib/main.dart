import 'package:example/singleton_with_riverpod.dart';
import 'package:flutter/material.dart';

void main() {
  //Old Pattern Example
  //runApp(const ProviderScope(child: OldPatternApp()));

  //Singleton Example
  // runApp(const SingletonExampleApp());

  //Singleton Example with Riverpod
  runApp(const SingletonWithRiverpodApp());
}

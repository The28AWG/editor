package com.example.example

import android.util.Log
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "TreeSitter"

        init {
            // libtree-sitter.so (с дефисом) — только через Dart FFI; грамматику подгружаем заранее.
            try {
                System.loadLibrary("tree_sitter_dart")
            } catch (e: UnsatisfiedLinkError) {
                Log.w(TAG, "preload libtree_sitter_dart.so: $e")
            }
        }
    }
}

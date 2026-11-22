package com.songyaning.openlistplayer

// audio_service 要求 Activity 继承 AudioServiceActivity（提供共享 FlutterEngine）
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.renderer.FlutterRenderer

class MainActivity : AudioServiceActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        // TODO(debug) 实验: 注释掉 GL 强制开关,走默认 ImageReader/AHardwareBuffer 路径。
        // 2026-11-22 真机证据: SurfaceTexture 路径下视频 BufferQueue acquired=0
        // (帧从不被消费),窗口 raster 120fps 全速空转画黑帧。
        // ImageReader 的 onImageAvailable 走独立回调线程,不依赖主线程 handler,
        // 可绕开主线程消息饿死问题。若此路不通,恢复下行注释。
        // FlutterRenderer.debugForceSurfaceProducerGlTextures = true
        super.onCreate(savedInstanceState)
    }
}

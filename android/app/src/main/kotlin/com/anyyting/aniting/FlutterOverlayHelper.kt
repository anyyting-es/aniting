package com.anyyting.aniting

import android.graphics.PixelFormat
import android.os.Build
import android.view.SurfaceView
import android.view.TextureView
import android.view.View
import android.view.ViewGroup

object FlutterOverlayHelper {

  /**
   * Find the top-level container holding the Flutter render surface.
   */
  fun findFlutterContainer(contentView: ViewGroup, excludeView: View? = null): ViewGroup? {
    for (i in contentView.childCount - 1 downTo 0) {
      val child = contentView.getChildAt(i)
      if (child === excludeView || child !is ViewGroup) continue
      if (findRenderSurface(child) != null) return child
    }
    return null
  }

  private fun findRenderSurface(root: ViewGroup): View? {
    for (i in 0 until root.childCount) {
      val child = root.getChildAt(i)
      if (child is SurfaceView || child is TextureView) return child
      if (child is ViewGroup) findRenderSurface(child)?.let { return it }
    }
    return null
  }

  /**
   * Apply SurfaceView.setCompositionOrder on API 36+; no-op on older APIs.
   */
  fun applyCompositionOrder(view: SurfaceView, order: Int) {
    if (Build.VERSION.SDK_INT >= 36) {
      try {
        view.compositionOrder = order
      } catch (_: Throwable) {}
    }
  }

  /**
   * Configure z-ordering so Flutter UI renders on top of the native video/subtitle surfaces
   * while maintaining transparency.
   */
  fun configureFlutterZOrder(contentView: ViewGroup, container: ViewGroup, compositionOrder: Int) {
    contentView.bringChildToFront(container)
    when (val surface = findRenderSurface(container)) {
      is SurfaceView -> {
        if (Build.VERSION.SDK_INT >= 36) {
          surface.setZOrderOnTop(false)
          surface.setZOrderMediaOverlay(false)
          surface.compositionOrder = compositionOrder
        } else {
          surface.setZOrderOnTop(compositionOrder > 0)
        }
        surface.holder.setFormat(PixelFormat.TRANSLUCENT)
      }
      is TextureView -> surface.isOpaque = false
    }
  }
}

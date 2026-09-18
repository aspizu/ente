package io.ente.photos.platform.memoryexport

import android.content.Context
import android.net.Uri
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.effect.LanczosResample
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import java.io.File

internal object MemoryExportService {
    fun exportMemory(
        context: Context,
        input: List<String>,
        output: File,
        onProgress: (Double) -> Unit,
        onCompleted: () -> Unit,
        onError: (Exception) -> Unit
    ): Transformer {
        val editedMediaItems = ArrayList<EditedMediaItem>()
        for (path in input) {
            val file = File(path)
            val uri = Uri.fromFile(file)
            val mediaItem = MediaItem.Builder()
                .setUri(uri)
                .setImageDurationMs(5000)
                .build()
            val videoEffects = ArrayList<Effect>()
            videoEffects.add(LanczosResample.scaleToFit(1080, 1920))
            videoEffects.add(
                Presentation.createForWidthAndHeight(
                    1080,
                    1920,
                    Presentation.LAYOUT_SCALE_TO_FIT
                )
            )
            val effects = Effects(emptyList(), videoEffects)
            val editedMediaItem = EditedMediaItem.Builder(mediaItem)
                .setFrameRate(30)
                .setEffects(effects)
                .build()
            editedMediaItems.add(editedMediaItem)
        }
        val sequence = EditedMediaItemSequence.withAudioAndVideoFrom(editedMediaItems)
        val composition = Composition.Builder(sequence).build()
        val transformer = Transformer.Builder(context)
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    onProgress(1.0)
                    onCompleted()
                }

                override fun onError(
                    composition: Composition,
                    exportResult: ExportResult,
                    exportException: ExportException
                ) {
                    onError(exportException)
                }
            })
            .build()
        onProgress(0.0)
        transformer.start(composition, output.path)
        return transformer
    }
}

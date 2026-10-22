package com.playfriends.play_friends

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.media.MediaPlayer
import android.net.Uri
import android.provider.OpenableColumns
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.concurrent.thread
import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.sin

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.playfriends.game_sound"
    private val PICK_PHOTO_CODE = 2001
    private val PICK_MUSIC_CODE = 2002
    private var pendingMethodResult: MethodChannel.Result? = null
    private var mediaPlayer: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> {
                    val sound = call.argument<String>("sound") ?: ""
                    playSound(sound)
                    result.success(true)
                }
                "pickPhotoFromGallery" -> {
                    pendingMethodResult = result
                    try {
                        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                            type = "image/*"
                            addCategory(Intent.CATEGORY_OPENABLE)
                        }
                        startActivityForResult(Intent.createChooser(intent, "Select Profile Photo"), PICK_PHOTO_CODE)
                    } catch (e: Exception) {
                        pendingMethodResult = null
                        result.error("PICKER_ERROR", e.message, null)
                    }
                }
                "pickMusicFromStorage" -> {
                    pendingMethodResult = result
                    try {
                        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                            type = "audio/*"
                            addCategory(Intent.CATEGORY_OPENABLE)
                        }
                        startActivityForResult(Intent.createChooser(intent, "Select Game Music Track"), PICK_MUSIC_CODE)
                    } catch (e: Exception) {
                        pendingMethodResult = null
                        result.error("PICKER_ERROR", e.message, null)
                    }
                }
                "playAudioFile" -> {
                    val path = call.argument<String>("path") ?: ""
                    val volume = (call.argument<Double>("volume") ?: 0.8).toFloat()
                    playMediaFile(path, volume)
                    result.success(true)
                }
                "pauseAudioFile" -> {
                    try {
                        mediaPlayer?.pause()
                    } catch (e: Exception) {
                        // Ignore
                    }
                    result.success(true)
                }
                "stopAudioFile" -> {
                    stopMediaFile()
                    result.success(true)
                }
                "setMusicVolume" -> {
                    val volume = (call.argument<Double>("volume") ?: 0.8).toFloat()
                    try {
                        mediaPlayer?.setVolume(volume, volume)
                    } catch (e: Exception) {
                        // Ignore
                    }
                    result.success(true)
                }
                "minimizeApp" -> {
                    try {
                        moveTaskToBack(true)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "saveLocalData" -> {
                    val key = call.argument<String>("key") ?: ""
                    val value = call.argument<String>("value") ?: ""
                    try {
                        val prefs = getSharedPreferences("play_friends_storage", Context.MODE_PRIVATE)
                        prefs.edit().putString(key, value).apply()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("STORAGE_ERROR", e.message, null)
                    }
                }
                "getLocalData" -> {
                    val key = call.argument<String>("key") ?: ""
                    try {
                        val prefs = getSharedPreferences("play_friends_storage", Context.MODE_PRIVATE)
                        val value = prefs.getString(key, null)
                        result.success(value)
                    } catch (e: Exception) {
                        result.success(null)
                    }
                }
                "removeLocalData" -> {
                    val key = call.argument<String>("key") ?: ""
                    try {
                        val prefs = getSharedPreferences("play_friends_storage", Context.MODE_PRIVATE)
                        prefs.edit().remove(key).apply()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("STORAGE_ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        val activeResult = pendingMethodResult ?: return
        pendingMethodResult = null

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            activeResult.success(null)
            return
        }

        val uri = data.data!!
        when (requestCode) {
            PICK_PHOTO_CODE -> {
                thread(start = true) {
                    try {
                        val inputStream = contentResolver.openInputStream(uri)
                        val originalBitmap = android.graphics.BitmapFactory.decodeStream(inputStream)
                        inputStream?.close()

                        if (originalBitmap != null) {
                            val maxDim = 512
                            val width = originalBitmap.width
                            val height = originalBitmap.height
                            val scaled = if (width > maxDim || height > maxDim) {
                                val scale = maxDim.toFloat() / kotlin.math.max(width, height)
                                val newW = (width * scale).toInt().coerceAtLeast(1)
                                val newH = (height * scale).toInt().coerceAtLeast(1)
                                android.graphics.Bitmap.createScaledBitmap(originalBitmap, newW, newH, true)
                            } else {
                                originalBitmap
                            }
                            val baos = java.io.ByteArrayOutputStream()
                            scaled.compress(android.graphics.Bitmap.CompressFormat.JPEG, 85, baos)
                            val bytes = baos.toByteArray()
                            val base64 = Base64.encodeToString(bytes, Base64.NO_WRAP)
                            val dataUri = "data:image/jpeg;base64,$base64"
                            runOnUiThread { activeResult.success(dataUri) }
                        } else {
                            val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                            if (bytes != null && bytes.isNotEmpty()) {
                                val base64 = Base64.encodeToString(bytes, Base64.NO_WRAP)
                                val mimeType = contentResolver.getType(uri) ?: "image/jpeg"
                                val dataUri = "data:$mimeType;base64,$base64"
                                runOnUiThread { activeResult.success(dataUri) }
                            } else {
                                runOnUiThread { activeResult.success(null) }
                            }
                        }
                    } catch (e: Exception) {
                        runOnUiThread { activeResult.error("READ_ERROR", e.message, null) }
                    }
                }
            }
            PICK_MUSIC_CODE -> {
                thread(start = true) {
                    try {
                        val fileName = getFileName(uri) ?: "Uploaded_Music_${System.currentTimeMillis()}.mp3"
                        val localFile = File(filesDir, fileName)
                        contentResolver.openInputStream(uri)?.use { input ->
                            localFile.outputStream().use { output ->
                                input.copyTo(output)
                            }
                        }
                        val title = fileName.substringBeforeLast(".")
                        val resultData = mapOf(
                            "title" to title,
                            "path" to localFile.absolutePath,
                            "fileName" to fileName
                        )
                        runOnUiThread { activeResult.success(resultData) }
                    } catch (e: Exception) {
                        runOnUiThread { activeResult.error("READ_ERROR", e.message, null) }
                    }
                }
            }
            else -> activeResult.success(null)
        }
    }

    private fun getFileName(uri: Uri): String? {
        var name: String? = null
        if (uri.scheme == "content") {
            val cursor = contentResolver.query(uri, null, null, null, null)
            cursor?.use {
                if (it.moveToFirst()) {
                    val nameIndex = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (nameIndex != -1) {
                        name = it.getString(nameIndex)
                    }
                }
            }
        }
        if (name == null) {
            name = uri.path?.substringAfterLast('/')
        }
        return name
    }

    private fun playMediaFile(path: String, volume: Float = 0.8f) {
        try {
            stopMediaFile()
            mediaPlayer = MediaPlayer().apply {
                setDataSource(path)
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_GAME)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                isLooping = true
                setVolume(volume, volume)
                prepare()
                start()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun stopMediaFile() {
        try {
            mediaPlayer?.stop()
            mediaPlayer?.release()
            mediaPlayer = null
        } catch (e: Exception) {
            // Ignore
        }
    }

    override fun onDestroy() {
        stopMediaFile()
        super.onDestroy()
    }

    private fun playSound(type: String) {
        thread(start = true) {
            try {
                when (type) {
                    "diceRoll" -> playDiceRoll()
                    "tokenMove" -> playTone(780.0, 70, 0.8)
                    "tokenCaptured" -> playCapture()
                    "tokenHome" -> playArpeggio(doubleArrayOf(880.0, 1108.0, 1320.0), 90)
                    "win" -> playFanfare()
                    "strike" -> playStrike()
                    "pocket" -> playPocket()
                    "cellTap" -> playTone(650.0, 45, 0.6)
                    "draw" -> playTone(350.0, 180, 0.6)
                    "hit" -> playHit()
                    "star" -> playArpeggio(doubleArrayOf(1046.0, 1318.0, 1568.0), 60)
                    "gameOver" -> playGameOver()
                    else -> playTone(500.0, 50, 0.5)
                }
            } catch (e: Exception) {
                // Ignore audio errors
            }
        }
    }

    private fun playAudio(samples: ShortArray, sampleRate: Int = 22050) {
        if (samples.isEmpty()) return
        try {
            val audioTrack = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_GAME)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(sampleRate)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build()
                )
                .setBufferSizeInBytes(samples.size * 2)
                .setTransferMode(AudioTrack.MODE_STATIC)
                .build()

            audioTrack.write(samples, 0, samples.size)
            audioTrack.play()
            val durationMs = (samples.size * 1000L / sampleRate) + 30
            Thread.sleep(durationMs)
            audioTrack.stop()
            audioTrack.release()
        } catch (e: Exception) {
            // AudioTrack error safeguard
        }
    }

    private fun playTone(freq: Double, durationMs: Int, volume: Double) {
        val sampleRate = 22050
        val numSamples = (sampleRate * (durationMs / 1000.0)).toInt().coerceAtLeast(1)
        val samples = ShortArray(numSamples)
        for (i in 0 until numSamples) {
            val t = i.toDouble() / sampleRate
            val envelope = when {
                i < 100 -> i / 100.0
                i > numSamples - 150 -> (numSamples - i) / 150.0
                else -> 1.0
            }
            val sample = sin(2.0 * PI * freq * t) * envelope * volume * Short.MAX_VALUE
            samples[i] = sample.toInt().coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
        }
        playAudio(samples, sampleRate)
    }

    private fun playDiceRoll() {
        val clickFreqs = doubleArrayOf(900.0, 720.0, 1100.0, 850.0)
        for (freq in clickFreqs) {
            playTone(freq, 30, 0.85)
            Thread.sleep(30)
        }
    }

    private fun playCapture() {
        val sampleRate = 22050
        val durationMs = 180
        val numSamples = (sampleRate * (durationMs / 1000.0)).toInt().coerceAtLeast(1)
        val samples = ShortArray(numSamples)
        for (i in 0 until numSamples) {
            val progress = i.toDouble() / numSamples
            val freq = 850.0 - (progress * 600.0)
            val envelope = (1.0 - progress) * 0.9
            val sample = sin(2.0 * PI * freq * (i.toDouble() / sampleRate)) * envelope * Short.MAX_VALUE
            samples[i] = sample.toInt().coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
        }
        playAudio(samples, sampleRate)
    }

    private fun playArpeggio(notes: DoubleArray, noteDurationMs: Int) {
        for (freq in notes) {
            playTone(freq, noteDurationMs, 0.75)
            Thread.sleep(15)
        }
    }

    private fun playFanfare() {
        val fanfare = doubleArrayOf(523.25, 659.25, 783.99, 1046.50)
        for (i in fanfare.indices) {
            val dur = if (i == fanfare.lastIndex) 300 else 100
            playTone(fanfare[i], dur, 0.85)
            Thread.sleep(25)
        }
    }

    private fun playStrike() {
        val sampleRate = 22050
        val numSamples = (sampleRate * 0.08).toInt().coerceAtLeast(1)
        val samples = ShortArray(numSamples)
        for (i in 0 until numSamples) {
            val progress = i.toDouble() / numSamples
            val decay = exp(-progress * 12.0)
            val freq = 450.0
            val sample = sin(2.0 * PI * freq * (i.toDouble() / sampleRate)) * decay * Short.MAX_VALUE * 0.95
            samples[i] = sample.toInt().coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
        }
        playAudio(samples, sampleRate)
    }

    private fun playPocket() {
        val sampleRate = 22050
        val numSamples = (sampleRate * 0.12).toInt().coerceAtLeast(1)
        val samples = ShortArray(numSamples)
        for (i in 0 until numSamples) {
            val progress = i.toDouble() / numSamples
            val decay = exp(-progress * 7.0)
            val freq = 200.0
            val sample = sin(2.0 * PI * freq * (i.toDouble() / sampleRate)) * decay * Short.MAX_VALUE * 0.9
            samples[i] = sample.toInt().coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
        }
        playAudio(samples, sampleRate)
    }

    private fun playHit() {
        playTone(150.0, 100, 0.9)
    }

    private fun playGameOver() {
        val sadNotes = doubleArrayOf(440.0, 392.0, 349.2, 293.6)
        for (freq in sadNotes) {
            playTone(freq, 120, 0.7)
            Thread.sleep(30)
        }
    }
}

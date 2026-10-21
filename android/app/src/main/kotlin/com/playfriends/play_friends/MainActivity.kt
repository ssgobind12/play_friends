package com.playfriends.play_friends

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread
import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.sin

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.playfriends.game_sound"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "play") {
                val sound = call.argument<String>("sound") ?: ""
                playSound(sound)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
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

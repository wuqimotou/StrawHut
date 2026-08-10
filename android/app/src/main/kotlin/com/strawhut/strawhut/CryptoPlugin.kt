package com.strawhut.strawhut

import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.security.SecureRandom
import java.security.spec.KeySpec
import javax.crypto.AEADBadTagException
import javax.crypto.Cipher
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec

class CryptoPlugin : FlutterPlugin, MethodCallHandler {

    companion object {
        private const val TAG = "CryptoPlugin"
        private const val CHANNEL_NAME = "com.strawhut.crypto"
        private const val AES_ALGORITHM = "AES/GCM/NoPadding"
        private const val GCM_TAG_LENGTH_BITS = 128
        private const val GCM_IV_LENGTH_BYTES = 12
        private const val KEY_LENGTH_BYTES = 32
    }

    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "generateKey" -> handleGenerateKey(result)
            "encrypt" -> handleEncrypt(call, result)
            "decrypt" -> handleDecrypt(call, result)
            "deriveKey" -> handleDeriveKey(call, result)
            else -> result.notImplemented()
        }
    }

    /**
     * 生成 32 字节随机密钥
     */
    private fun handleGenerateKey(result: Result) {
        try {
            val key = ByteArray(KEY_LENGTH_BYTES)
            SecureRandom().nextBytes(key)
            result.success(key)
        } catch (e: Exception) {
            Log.e(TAG, "generateKey failed", e)
            result.error("KEY_GENERATION_FAILED", "Failed to generate key: ${e.message}", null)
        }
    }

    /**
     * AES-256-GCM 加密
     * 输入: plaintext (ByteArray), key (ByteArray)
     * 输出: Map { "ciphertext": ByteArray, "iv": ByteArray }
     *
     * 注意: Android Cipher.doFinal() 在 GCM 模式下输出 ciphertext || Tag(16 bytes)，
     * 与 pointycastle 格式一致
     */
    private fun handleEncrypt(call: MethodCall, result: Result) {
        try {
            val plaintext = call.argument<ByteArray>("plaintext")
                ?: return result.error("INVALID_ARGS", "plaintext is required", null)
            val key = call.argument<ByteArray>("key")
                ?: return result.error("INVALID_ARGS", "key is required", null)

            if (key.size != KEY_LENGTH_BYTES) {
                return result.error(
                    "INVALID_KEY_SIZE",
                    "Key must be 32 bytes, got ${key.size}",
                    null
                )
            }

            // 生成 12 字节 IV
            val iv = ByteArray(GCM_IV_LENGTH_BYTES)
            SecureRandom().nextBytes(iv)

            val secretKey = SecretKeySpec(key, "AES")
            val cipher = Cipher.getInstance(AES_ALGORITHM)
            val gcmSpec = GCMParameterSpec(GCM_TAG_LENGTH_BITS, iv)
            cipher.init(Cipher.ENCRYPT_MODE, secretKey, gcmSpec)

            // doFinal 输出: ciphertext || GCM Tag (16 bytes)
            val ciphertextWithTag = cipher.doFinal(plaintext)

            val resultMap = HashMap<String, Any>()
            resultMap["ciphertext"] = ciphertextWithTag
            resultMap["iv"] = iv

            result.success(resultMap)
        } catch (e: Exception) {
            Log.e(TAG, "encrypt failed", e)
            result.error("ENCRYPTION_FAILED", "Encryption failed: ${e.message}", null)
        }
    }

    /**
     * AES-256-GCM 解密
     * 输入: ciphertext (ByteArray), key (ByteArray), iv (ByteArray)
     * 支持 12 字节和 16 字节 IV 长度（向后兼容）
     */
    private fun handleDecrypt(call: MethodCall, result: Result) {
        try {
            val ciphertext = call.argument<ByteArray>("ciphertext")
                ?: return result.error("INVALID_ARGS", "ciphertext is required", null)
            val key = call.argument<ByteArray>("key")
                ?: return result.error("INVALID_ARGS", "key is required", null)
            val iv = call.argument<ByteArray>("iv")
                ?: return result.error("INVALID_ARGS", "iv is required", null)

            if (key.size != KEY_LENGTH_BYTES) {
                return result.error(
                    "INVALID_KEY_SIZE",
                    "Key must be 32 bytes, got ${key.size}",
                    null
                )
            }

            if (iv.isEmpty() || iv.size > 16) {
                return result.error(
                    "INVALID_IV_SIZE",
                    "IV must be 1-16 bytes, got ${iv.size}",
                    null
                )
            }

            val secretKey = SecretKeySpec(key, "AES")
            val cipher = Cipher.getInstance(AES_ALGORITHM)
            // GCMParameterSpec 接受 1-16 字节的 IV
            val gcmSpec = GCMParameterSpec(GCM_TAG_LENGTH_BITS, iv)
            cipher.init(Cipher.DECRYPT_MODE, secretKey, gcmSpec)

            val plaintext = cipher.doFinal(ciphertext)
            result.success(plaintext)
        } catch (e: AEADBadTagException) {
            Log.w(TAG, "Decryption failed: authentication tag mismatch")
            result.error("DECRYPTION_FAILED", "Decryption failed: authentication tag mismatch", null)
        } catch (e: Exception) {
            Log.e(TAG, "decrypt failed", e)
            result.error("DECRYPTION_FAILED", "Decryption failed: ${e.message}", null)
        }
    }

    /**
     * PBKDF2 密钥派生
     * 输入: passphrase (String), salt (ByteArray), iterations (Int)
     * 优先使用 AndroidOpenSSL Provider，不可用时回退到默认 Provider
     * 输出: 派生密钥 (ByteArray, 32 字节)
     */
    private fun handleDeriveKey(call: MethodCall, result: Result) {
        try {
            val passphrase = call.argument<String>("passphrase")
                ?: return result.error("INVALID_ARGS", "passphrase is required", null)
            val salt = call.argument<ByteArray>("salt")
                ?: return result.error("INVALID_ARGS", "salt is required", null)
            val iterations = call.argument<Int>("iterations")
                ?: return result.error("INVALID_ARGS", "iterations is required", null)

            if (iterations <= 0) {
                return result.error(
                    "INVALID_ARGS",
                    "iterations must be positive, got $iterations",
                    null
                )
            }

            val keySpec: KeySpec = PBEKeySpec(
                passphrase.toCharArray(),
                salt,
                iterations,
                256 // 256-bit key
            )

            // 优先使用 AndroidOpenSSL Provider，不可用时回退到默认 Provider
            val keyFactory = try {
                SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256", "AndroidOpenSSL")
            } catch (e: Exception) {
                Log.w(TAG, "AndroidOpenSSL provider unavailable, falling back to default", e)
                SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
            }

            val secretKey = keyFactory.generateSecret(keySpec)
            val derivedKey = secretKey.encoded

            result.success(derivedKey)
        } catch (e: Exception) {
            Log.e(TAG, "deriveKey failed", e)
            result.error("KEY_DERIVATION_FAILED", "Key derivation failed: ${e.message}", null)
        }
    }
}

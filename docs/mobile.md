# Mobile App Security

> Android + iOS, SDK v0.5 awareness.

### 11. Mobile App — SDK v0.5 Awareness

CEX Mobile SDK v0.5 có một số **GAP phải fix trước go-live:**
- ⚠️ TOTP anti-replay (server-side workaround OK)
- ⚠️ Device Attestation (Play Integrity / iOS App Attest)
- ⚠️ TOTP secret trong Mobile TEE (Android Keystore / iOS Secure Enclave)
- ⚠️ Passkey (FIDO2) — chưa có
- ⚠️ Certificate Pinning enforcement
- ⚠️ Liveness Detection cho Face Recognition

**Android:**
- ✅ Android Keystore + EncryptedSharedPreferences (không plaintext SharedPreferences)
- ✅ Token thông thường: MasterKey không cần userAuth. Seed/private key: `setUserAuthenticationRequired(true)`.
- ✅ BiometricPrompt + Keystore với `requireUserAuth = true`. Biometric token phải Backend validate.
- ✅ OkHttp CertificatePinner với backup pin, expiration ~2030 + xoay vòng
- ✅ FLAG_SECURE + `onFilterTouchEventForSecurity` cho màn hình rút tiền / seed / OTP
- ✅ Play Integrity API *(thay thế SafetyNet — Google đã ngừng hỗ trợ SafetyNet từ 01/2025)*
- ✅ ProGuard/R8 obfuscation cho release
- ✅ Refresh token rotation: KHÔNG xóa token cũ trước khi lưu token mới thành công (race condition)

**iOS:**
- ✅ Keychain Services + Secure Enclave (private key cho non-custodial, nếu có)
- ✅ Face ID/Touch ID + Keychain với `biometryCurrentSet` flag
- ✅ TrustKit / URLSessionDelegate cho certificate pinning với backup pin
- ✅ ATS bật mặc định, không cho HTTP
- ✅ Anti-jailbreak detection (heuristic, không thay thế server validation)
- ✅ Strip symbol + tắt DEBUG cho release

**Cả 2:**
- ❌ KHÔNG hardcode API endpoint/key trong mobile code
- ✅ **Request signing** với HMAC + apiSecret (gắn user + device), timestamp ±5 phút, nonce 1 lần dùng (Redis)
- ✅ **Address Hijacking defense:** kiểm tra clipboard trước khi paste địa chỉ
- ✅ Device attestation: Firebase App Check (Android) / App Attest (iOS) — bắt buộc trước go-live

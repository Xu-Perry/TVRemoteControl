import CommonCrypto
import Foundation
import Security
import TVRemoteCore

enum TextFormEncryption {
    static func encryptedPayload(text: String, publicKeyBase64: String) throws -> (
        encKey: String, encryptedText: String
    ) {
        guard let publicKeyData = Data(base64Encoded: publicKeyBase64) else {
            throw RemoteControlError.textEncryptionFailed
        }

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
        ]
        guard
            let publicKey = SecKeyCreateWithData(
                publicKeyData as CFData,
                attributes as CFDictionary,
                nil
            )
        else {
            throw RemoteControlError.textEncryptionFailed
        }

        var aesKey = Data(count: kCCKeySizeAES128)
        var aesIV = Data(count: kCCBlockSizeAES128)
        guard
            aesKey.withUnsafeMutableBytes({ SecRandomCopyBytes(kSecRandomDefault, kCCKeySizeAES128, $0.baseAddress!) })
                == errSecSuccess,
            aesIV.withUnsafeMutableBytes({ SecRandomCopyBytes(kSecRandomDefault, kCCBlockSizeAES128, $0.baseAddress!) })
                == errSecSuccess
        else {
            throw RemoteControlError.textEncryptionFailed
        }

        let commonKey = aesKey + Data(":".utf8) + aesIV
        guard
            let encKeyData = SecKeyCreateEncryptedData(
                publicKey,
                .rsaEncryptionPKCS1,
                commonKey as CFData,
                nil
            ) as Data?
        else {
            throw RemoteControlError.textEncryptionFailed
        }

        let encryptedText = try aesCBCEncrypt(data: Data(text.utf8), key: aesKey, iv: aesIV)
        return (
            encKey: encKeyData.base64EncodedString(),
            encryptedText: encryptedText.base64EncodedString()
        )
    }

    private static func aesCBCEncrypt(data: Data, key: Data, iv: Data) throws -> Data {
        let bufferSize = data.count + kCCBlockSizeAES128
        var output = Data(count: bufferSize)
        var encryptedLength = 0

        let status = output.withUnsafeMutableBytes { outputBytes in
            data.withUnsafeBytes { dataBytes in
                key.withUnsafeBytes { keyBytes in
                    iv.withUnsafeBytes { ivBytes in
                        CCCrypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress,
                            key.count,
                            ivBytes.baseAddress,
                            dataBytes.baseAddress,
                            data.count,
                            outputBytes.baseAddress,
                            bufferSize,
                            &encryptedLength
                        )
                    }
                }
            }
        }

        guard status == kCCSuccess else {
            throw RemoteControlError.textEncryptionFailed
        }

        return output.prefix(encryptedLength)
    }
}

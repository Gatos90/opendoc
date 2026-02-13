import { createCipheriv, createDecipheriv, randomBytes } from "node:crypto"

/**
 * Encrypt an environment variable map using AES-256-GCM.
 * Format: base64(iv[12] + authTag[16] + ciphertext)
 */
export function encryptEnv(env: Record<string, string>, keyHex: string): string {
  const key = Buffer.from(keyHex, "hex")
  const iv = randomBytes(12)
  const cipher = createCipheriv("aes-256-gcm", key, iv)
  const plaintext = JSON.stringify(env)
  const encrypted = Buffer.concat([cipher.update(plaintext, "utf8"), cipher.final()])
  const tag = cipher.getAuthTag()
  return Buffer.concat([iv, tag, encrypted]).toString("base64")
}

/**
 * Decrypt an environment variable map encrypted with encryptEnv().
 * Returns the original Record<string, string>.
 */
export function decryptEnv(encoded: string, keyHex: string): Record<string, string> {
  const key = Buffer.from(keyHex, "hex")
  const data = Buffer.from(encoded, "base64")
  const iv = data.subarray(0, 12)
  const tag = data.subarray(12, 28)
  const ciphertext = data.subarray(28)
  const decipher = createDecipheriv("aes-256-gcm", key, iv)
  decipher.setAuthTag(tag)
  const decrypted = Buffer.concat([decipher.update(ciphertext), decipher.final()])
  return JSON.parse(decrypted.toString("utf8"))
}

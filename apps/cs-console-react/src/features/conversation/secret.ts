const SECRET =
  /\b(otp|pin|password|passwd|kata\s+sandi|sandi|cvv|cvc|kode\s+(otp|verifikasi|keamanan)|nomor\s+kartu)\b/i
const ASK =
  /\b(kirim|kirimkan|berikan|beritahu|beritahukan|beri\s+tahu|sebutkan|informasikan|bagikan|ketik|ketikkan|tulis|tuliskan|masukkan|input|share|send|give|provide|tell)\b/i
const HOW_MUCH = /\b(otp|pin|password|sandi|cvv|kode)\b[^.!?\n]{0,25}\bberapa\b/i
const NEGATION = /\b(jangan|tidak\s+pernah|tidak\s+akan|bukan|never|not|don't)\b/i

export function requestsSecret(text: string) {
  return text
    .split(/[.!?\n]+/)
    .some(
      (sentence) =>
        SECRET.test(sentence) && (ASK.test(sentence) || HOW_MUCH.test(sentence)) && !NEGATION.test(sentence),
    )
}

# Frame golden dari kode OLT

File `.bin` di folder ini dihasilkan oleh `gen.cc` yang dikompilasi bersama source server OLT (`legacy/olt-service-all`: `libs/IPackage.cc`, `libs/RawPackage.cc`, `libs/CMCrypt.cc`, `libs/minilzo.cc`). Isinya data sintetis (rekening `GOLD01`, kunci uji `0123456789ABCDEF` dan `0123456789ABCDEF0123456789ABCDEF`), bukan data atau kunci produksi.

| File | Isi |
|---|---|
| `order_plain.bin` | `IPKG_REP_NEW_ORDER` tanpa kompresi |
| `order_compressed.bin` | Sama, dikompres `CIPackage::CompressPackage` (Snappy) |
| `order_compressed_aes_ecb.bin` | Terkompresi lalu dienkripsi `CMCrypt` (rijndael-128 ECB, kunci 16 karakter) dengan layout `CGPackage::EncryptAES` setelah header 23 byte |
| `order_large_compressed.bin` | Order matched dengan payload besar, terkompresi |
| `trade_plain.bin` | `IPKG_REP_TRADE` tanpa kompresi |
| `trade_aes_ecb256.bin` | Trade dienkripsi `CMCrypt` dengan kunci 32 karakter (AES-256) |
| `trade_compressed.bin` | Trade terkompresi |
| `heartbeat.bin` | `CIPackage(0, IPKG_HEART_BEAT)` dengan cap waktu |

Membuat ulang (dari root repo, butuh folder `legacy/olt-service-all` lokal):

```
docker run --rm -v "$PWD/legacy/olt-service-all:/olt:ro" -v "$PWD/services/trade-relay/internal/protocol/testdata/olt:/work" -w /work gcc:14 sh -c \
  "apt-get update -qq && apt-get install -y -qq libsnappy-dev libbsd-dev libmcrypt-dev && \
   g++ -std=c++17 -w -I/olt/inc -I/olt/libs gen.cc /olt/libs/IPackage.cc /olt/libs/RawPackage.cc /olt/libs/CMCrypt.cc /olt/libs/minilzo.cc -lsnappy -lbsd -lmcrypt -o /tmp/gen && /tmp/gen"
```

Frame asli dari UAT OLT, bila sudah tersedia, ditambahkan ke folder terpisah dan diuji dengan cara yang sama.

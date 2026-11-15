#include <cstdio>
#include <cstring>
#include <string>
#include <arpa/inet.h>
#include "IPackage.h"
#include "CMCrypt.h"
#include <cstdlib>

void *xmalloc(size_t size) { return malloc(size); }

static void save(const char *name, const char *data, size_t len) {
    FILE *f = fopen(name, "wb");
    fwrite(data, 1, len, f);
    fclose(f);
}

static CIPackage *order(uint8_t status, const char *orderId, uint64_t open, uint64_t remain, uint64_t traded) {
    CIPackage *o = new CIPackage(4096, IPKG_REP_NEW_ORDER);
    o->AddInt8(status);
    o->AddString(orderId);
    o->AddString("");
    o->AddString("IDX-0001");
    o->AddInt32(20261116);
    o->AddInt32(91501);
    o->AddInt32(91502);
    o->AddString("RG");
    o->AddString("RG");
    o->AddInt8(0);
    o->AddString("GOLD01");
    o->AddString("ALT");
    o->AddInt8(1);
    o->AddInt8(0);
    o->AddString("BBCA");
    o->AddInt32(9150);
    o->AddInt64(open);
    o->AddInt64(remain);
    o->AddInt64(traded);
    o->AddString("trader01");
    o->AddString("");
    o->AddInt8(6);
    o->AddInt8(0);
    o->AddString("SID123");
    o->AddString("CLIENT1");
    o->UpdatePackageTimeStamp();
    return o;
}

static CIPackage *trade(const char *tradeId, uint64_t volume) {
    CIPackage *o = new CIPackage(4096, IPKG_REP_TRADE);
    o->AddString("ORD-GOLD-1");
    o->AddString("IDX-0001");
    o->AddString(tradeId);
    o->AddInt32(20261116);
    o->AddInt32(93005);
    o->AddString("RG");
    o->AddString("RG");
    o->AddInt8(0);
    o->AddString("GOLD01");
    o->AddString("ALT");
    o->AddInt8(1);
    o->AddInt8(1);
    o->AddString("BBCA");
    o->AddInt32(9175);
    o->AddInt64(volume);
    o->AddString("CPTY");
    o->AddInt8(6);
    o->UpdatePackageTimeStamp();
    return o;
}

static std::string encrypt(CIPackage *p, const char *key) {
    const char *data = (const char *)*p;
    uint32_t total = p->GetPackageLength();
    uint16_t flags = ntohs(*((uint16_t *)(data + 10)));
    CMCrypt cm(key, strlen(key), "0000000000000000");
    uint32_t dataSize = total - IHEADER_LENGTH;
    uint32_t encLen = cm.CalcEncBufferSize(dataSize);
    std::string out(IHEADER_LENGTH + 4 + encLen, '\0');
    memcpy(&out[0], data, IHEADER_LENGTH);
    memcpy(&out[IHEADER_LENGTH + 4], data + IHEADER_LENGTH, dataSize);
    if (cm.FastEncrypt(&out[IHEADER_LENGTH + 4], encLen) != 0) {
        fprintf(stderr, "encrypt failed\n");
    }
    *((uint32_t *)(&out[IHEADER_LENGTH])) = htonl(total);
    *((uint32_t *)(&out[4])) = htonl((uint32_t)out.size());
    *((uint16_t *)(&out[10])) = htons(flags | 0x0001);
    return out;
}

int main() {
    CIPackage *o = order(1, "ORD-GOLD-1", 2500, 1500, 1000);
    save("order_plain.bin", (const char *)*o, o->GetPackageLength());
    o->CompressPackage();
    save("order_compressed.bin", (const char *)*o, o->GetPackageLength());
    std::string enc = encrypt(o, "0123456789ABCDEF");
    save("order_compressed_aes_ecb.bin", enc.data(), enc.size());

    CIPackage *t = trade("TRD-GOLD-1", 1500);
    save("trade_plain.bin", (const char *)*t, t->GetPackageLength());
    std::string tenc = encrypt(t, "0123456789ABCDEF0123456789ABCDEF");
    save("trade_aes_ecb256.bin", tenc.data(), tenc.size());
    t->CompressPackage();
    save("trade_compressed.bin", (const char *)*t, t->GetPackageLength());

    CIPackage hb(0, IPKG_HEART_BEAT);
    hb.UpdatePackageTimeStamp();
    save("heartbeat.bin", (const char *)hb, hb.GetPackageLength());

    CIPackage *big = order(2, "ORD-GOLD-2", 100000, 0, 100000);
    for (int i = 0; i < 200; i++) big->AddString("padding-to-exercise-snappy-on-a-larger-payload");
    big->CompressPackage();
    save("order_large_compressed.bin", (const char *)*big, big->GetPackageLength());
    printf("ok\n");
    return 0;
}

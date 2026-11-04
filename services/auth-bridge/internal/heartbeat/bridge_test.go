package heartbeat

import (
	"encoding/json"
	"fmt"
	"strings"
	"testing"
	"time"

	"olt-social/auth-bridge/internal/olt"
)

func TestBridgeDetailInJWTModeCarriesKeyIDsAndClaimRules(t *testing.T) {
	detail := Bridge{
		AppEnv:   "development",
		OLTMode:  "jwt",
		Issuer:   "olt",
		Audience: "olt-social",
		MaxTTL:   15 * time.Minute,
		Keys:     []olt.KeyInfo{{Kid: "dev-olt-1", Alg: "EdDSA"}},
	}.Detail()
	got, err := json.Marshal(detail)
	if err != nil {
		t.Fatal(err)
	}
	want := `{"app_env":"development","audience":"olt-social","issuer":"olt","key_count":1,` +
		`"keys":[{"alg":"EdDSA","kid":"dev-olt-1"}],"max_ttl_seconds":900,"olt_mode":"jwt"}`
	if string(got) != want {
		t.Fatalf("detail = %s\nwant   %s", got, want)
	}
}

func TestBridgeDetailInMockModeHasNoKeysOrClaimRules(t *testing.T) {
	got, err := json.Marshal(Bridge{AppEnv: "development", OLTMode: "mock", Issuer: "olt", Audience: "olt-social"}.Detail())
	if err != nil {
		t.Fatal(err)
	}
	if want := `{"app_env":"development","key_count":0,"keys":[],"olt_mode":"mock"}`; string(got) != want {
		t.Fatalf("detail = %s, want %s", got, want)
	}
}

func TestBridgeDetailCapsKeysAndKidLength(t *testing.T) {
	keys := make([]olt.KeyInfo, 0, 30)
	for i := range 30 {
		keys = append(keys, olt.KeyInfo{Kid: fmt.Sprintf("olt-%02d-%s", i, strings.Repeat("k", 200)), Alg: "ES256"})
	}
	detail := Bridge{OLTMode: "jwt", Keys: keys}.Detail()
	shown := detail["keys"].([]map[string]string)
	if detail["key_count"] != 30 || len(shown) != maxKeys || len([]rune(shown[0]["kid"])) != maxKidChars {
		t.Fatalf("key_count = %v, shown = %d, kid = %d", detail["key_count"], len(shown), len(shown[0]["kid"]))
	}
	raw, _ := json.Marshal(detail)
	if len(raw) > 8192 {
		t.Fatalf("detail %d bytes, limit database 8192", len(raw))
	}
}

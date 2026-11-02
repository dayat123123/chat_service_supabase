package csadmin

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"olt-social/nasabah-gateway/internal/jwt"
)

type integrationServer struct {
	public  ed25519.PublicKey
	exp     time.Time
	mu      sync.Mutex
	issued  int
	seenJTI map[string]bool
	claims  []map[string]any
}

func (s *integrationServer) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/csAdmin/integration/token" || r.Method != http.MethodPost || r.Header.Get("Content-Type") != "application/json" {
		http.NotFound(w, r)
		return
	}
	var body struct {
		Assertion string `json:"Assertion"`
	}
	_ = json.NewDecoder(r.Body).Decode(&body)
	claims, ok := s.verify(body.Assertion)
	s.mu.Lock()
	defer s.mu.Unlock()
	if !ok || s.seenJTI[claims["jti"].(string)] {
		w.WriteHeader(http.StatusUnauthorized)
		_, _ = w.Write([]byte(`{"message":"Invalid client assertion.","data":{}}`))
		return
	}
	s.seenJTI[claims["jti"].(string)] = true
	s.claims = append(s.claims, claims)
	s.issued++
	token, _ := jwt.Sign(map[string]any{"alg": "HS256", "typ": "JWS"}, map[string]any{"iss": "auth0", "loginId": "web-cs", "exp": s.exp.Unix()}, []byte("legacy"))
	_ = json.NewEncoder(w).Encode(map[string]any{"message": "Successfully issued integration token.",
		"data": map[string]any{"Token": token, "ClientId": "web-cs", "ExpiresIn": 900}})
}

func (s *integrationServer) verify(assertion string) (map[string]any, bool) {
	parts := strings.Split(assertion, ".")
	if len(parts) != 3 {
		return nil, false
	}
	head, _ := base64.RawURLEncoding.DecodeString(parts[0])
	if !strings.Contains(string(head), `"alg":"EdDSA"`) {
		return nil, false
	}
	sig, _ := base64.RawURLEncoding.DecodeString(parts[2])
	if !ed25519.Verify(s.public, []byte(parts[0]+"."+parts[1]), sig) {
		return nil, false
	}
	raw, _ := base64.RawURLEncoding.DecodeString(parts[1])
	var claims map[string]any
	if json.Unmarshal(raw, &claims) != nil {
		return nil, false
	}
	_, hasJTI := claims["jti"].(string)
	return claims, hasJTI
}

func newIntegration(t *testing.T, exp time.Time) (*integrationServer, *httptest.Server, ed25519.PrivateKey) {
	t.Helper()
	public, private, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	fake := &integrationServer{public: public, exp: exp, seenJTI: map[string]bool{}}
	server := httptest.NewServer(fake)
	t.Cleanup(server.Close)
	return fake, server, private
}

func TestSessionExchangesASignedAssertionOnceAndRefreshesBeforeExpiry(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	fake, server, key := newIntegration(t, now.Add(15*time.Minute))
	s := NewSession(server.URL+"/csAdmin/", "web-cs", key, nil)
	s.now = func() time.Time { return now }

	first, err := s.Token(context.Background())
	if err != nil || first == "" {
		t.Fatalf("token %q err %v", first, err)
	}
	second, _ := s.Token(context.Background())
	if second != first || fake.issued != 1 {
		t.Fatalf("token must be reused, issued = %d", fake.issued)
	}
	claims := fake.claims[0]
	if claims["iss"] != "web-cs" || claims["sub"] != "web-cs" || claims["aud"] != "csAdminEL" {
		t.Fatalf("assertion claims = %v", claims)
	}
	if claims["iat"].(float64) != float64(now.Unix()) || claims["exp"].(float64)-claims["iat"].(float64) != 60 {
		t.Fatalf("assertion must live 60 seconds, claims = %v", claims)
	}

	now = now.Add(15*time.Minute - 30*time.Second)
	_, _ = s.Token(context.Background())
	if fake.issued != 2 || fake.claims[1]["jti"] == fake.claims[0]["jti"] {
		t.Fatalf("token must be refreshed with a fresh assertion, issued = %d", fake.issued)
	}
}

func TestSessionInvalidateForcesANewExchange(t *testing.T) {
	fake, server, key := newIntegration(t, time.Now().Add(time.Hour))
	s := NewSession(server.URL+"/csAdmin", "web-cs", key, nil)
	token, _ := s.Token(context.Background())
	s.Invalidate("some-other-token")
	_, _ = s.Token(context.Background())
	if fake.issued != 1 {
		t.Fatal("invalidating a stale token must keep the current one")
	}
	s.Invalidate(token)
	_, _ = s.Token(context.Background())
	if fake.issued != 2 {
		t.Fatal("invalidating the current token must exchange again")
	}
}

func TestSessionReportsARefusedAssertion(t *testing.T) {
	_, server, _ := newIntegration(t, time.Now().Add(time.Hour))
	_, otherKey, _ := ed25519.GenerateKey(rand.Reader)
	s := NewSession(server.URL+"/csAdmin", "web-cs", otherKey, nil)
	if _, err := s.Token(context.Background()); !errors.Is(err, ErrRefused) {
		t.Fatalf("a key csAdmin does not know must be refused, err = %v", err)
	}
}

func TestSessionIsNotConfiguredWithoutURLClientOrKey(t *testing.T) {
	_, key, _ := ed25519.GenerateKey(rand.Reader)
	if NewSession("http://csadmin", "web-cs", nil, nil).Configured() ||
		NewSession("", "web-cs", key, nil).Configured() ||
		NewSession("http://csadmin", "", key, nil).Configured() {
		t.Fatal("missing url, client id, or key must not count as configured")
	}
	if !NewSession("http://csadmin", "web-cs", key, nil).Configured() {
		t.Fatal("complete settings must count as configured")
	}
}

func TestPrivateKeysParseFromPKCS8AndYieldTheConfigPublicKey(t *testing.T) {
	public, private, _ := ed25519.GenerateKey(rand.Reader)
	der, _ := x509.MarshalPKCS8PrivateKey(private)
	parsed, err := ParsePrivateKey(pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der}))
	if err != nil || !parsed.Equal(private) {
		t.Fatalf("parse: %v", err)
	}
	line := PublicKeyLine(parsed)
	if strings.ContainsAny(line, "=\n ") {
		t.Fatalf("config line must be one unpadded base64 line, got %q", line)
	}
	spki, err := base64.RawStdEncoding.DecodeString(line)
	if err != nil {
		t.Fatal(err)
	}
	decoded, err := x509.ParsePKIXPublicKey(spki)
	if err != nil || !public.Equal(decoded) {
		t.Fatalf("public key line does not round-trip: %v", err)
	}
	windows := strings.ReplaceAll(string(pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der})), "\n", "\r\n")
	if parsed, err := ParsePrivateKey([]byte(strings.TrimSuffix(windows, "\n"))); err != nil || !parsed.Equal(private) {
		t.Fatalf("CRLF keys with a stray carriage return must parse: %v", err)
	}
	if _, err := ParsePrivateKey([]byte("not a key")); err == nil {
		t.Fatal("garbage must be rejected")
	}
	rsaLike := pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: []byte{0x30, 0x00}})
	if _, err := ParsePrivateKey(rsaLike); err == nil {
		t.Fatal("non-Ed25519 keys must be rejected")
	}
}

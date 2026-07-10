package middleware

import "testing"

func TestBearerTokenFromHeader(t *testing.T) {
	t.Parallel()

	token, err := bearerTokenFromHeader("Bearer abc123")
	if err != nil {
		t.Fatalf("bearerTokenFromHeader returned error: %v", err)
	}

	if token != "abc123" {
		t.Fatalf("expected token abc123, got %q", token)
	}
}

func TestBearerTokenFromHeaderRejectsMalformedHeader(t *testing.T) {
	t.Parallel()

	if _, err := bearerTokenFromHeader("abc123"); err == nil {
		t.Fatal("expected malformed header error, got nil")
	}
}

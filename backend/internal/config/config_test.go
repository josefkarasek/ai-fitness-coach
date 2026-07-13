package config

import (
	"os"
	"testing"
)

func TestPrepareFirebaseCredentialsCreatesRuntimeFile(t *testing.T) {
	t.Setenv("GOOGLE_APPLICATION_CREDENTIALS", "")
	t.Setenv("FIREBASE_ADMIN_JSON", "{\"type\":\"service_account\",\"project_id\":\"demo\"}")
	t.Setenv("TMPDIR", t.TempDir())

	prepareFirebaseCredentials()

	credentialsPath := os.Getenv("GOOGLE_APPLICATION_CREDENTIALS")
	if credentialsPath == "" {
		t.Fatal("expected GOOGLE_APPLICATION_CREDENTIALS to be set")
	}

	contents, err := os.ReadFile(credentialsPath)
	if err != nil {
		t.Fatalf("os.ReadFile(%q) returned error: %v", credentialsPath, err)
	}

	if string(contents) != "{\"type\":\"service_account\",\"project_id\":\"demo\"}" {
		t.Fatalf("expected file contents to match FIREBASE_ADMIN_JSON, got %q", string(contents))
	}
}

func TestPrepareFirebaseCredentialsKeepsExplicitPath(t *testing.T) {
	t.Setenv("GOOGLE_APPLICATION_CREDENTIALS", "/tmp/existing-firebase-admin.json")
	t.Setenv("FIREBASE_ADMIN_JSON", "{\"ignored\":true}")

	prepareFirebaseCredentials()

	if got := os.Getenv("GOOGLE_APPLICATION_CREDENTIALS"); got != "/tmp/existing-firebase-admin.json" {
		t.Fatalf("expected existing credentials path to be preserved, got %q", got)
	}
}

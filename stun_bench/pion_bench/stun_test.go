package stunbench

import (
	"encoding/base64"
	"encoding/hex"
	"net"
	"testing"

	"github.com/pion/stun"
)

func BenchmarkBindingRequestEncode(b *testing.B) {
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		stun.MustBuild(stun.BindingRequest, stun.TransactionID)
	}
}

func BenchmarkBindingRequestDecode(b *testing.B) {
	b.ReportAllocs()
	bindingRequest := stun.MustBuild(stun.BindingRequest, stun.TransactionID)
	m := stun.New()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		m.Reset()
		if err := stun.Decode(bindingRequest.Raw, m); err != nil {
			b.Fatal(err)
		}
	}

}

func BenchmarkBindingResponseEncode(b *testing.B) {
	b.ReportAllocs()
	tID := stun.NewTransactionID()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		stun.MustBuild(stun.BindingSuccess, stun.NewTransactionIDSetter(tID),
			&stun.XORMappedAddress{IP: net.IPv4(213, 1, 223, 5), Port: 1234})
	}
}

func BenchmarkBindingResponseDecode(b *testing.B) {
	b.ReportAllocs()
	tID := stun.NewTransactionID()
	bindingResponse := stun.MustBuild(stun.BindingSuccess, stun.NewTransactionIDSetter(tID),
		&stun.XORMappedAddress{IP: net.IPv4(213, 1, 223, 5), Port: 1234})
	m := stun.New()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		m.Reset()
		if err := stun.Decode(bindingResponse.Raw, m); err != nil {
			b.Fatal(err)
		}
	}
}

func BenchmarkMessageFullEncode(b *testing.B) {
	b.ReportAllocs()
	tID := stun.NewTransactionID()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		stun.MustBuild(stun.BindingSuccess, stun.NewTransactionIDSetter(tID),
			stun.NewUsername("someusername"),
			stun.NewRealm("somerealm"),
			&stun.XORMappedAddress{IP: net.IPv4(213, 1, 223, 5), Port: 1234},
			stun.NewShortTermIntegrity("somepwd"),
			stun.Fingerprint,
		)
	}
}

func BenchmarkMessageFullDecode(b *testing.B) {
	b.ReportAllocs()
	tID := stun.NewTransactionID()
	messageFull := stun.MustBuild(stun.BindingSuccess, stun.NewTransactionIDSetter(tID),
		stun.NewUsername("someusername"),
		stun.NewRealm("somerealm"),
		&stun.XORMappedAddress{IP: net.IPv4(213, 1, 223, 5), Port: 1234},
		stun.NewShortTermIntegrity("somepwd"),
		stun.Fingerprint,
	)
	m := stun.New()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		m.Reset()
		if err := stun.Decode(messageFull.Raw, m); err != nil {
			b.Fatal(err)
		}
	}
}

func BenchmarkAuthenticateSt(b *testing.B) {
	b.ReportAllocs()
	tID := stun.NewTransactionID()
	messageFull := stun.MustBuild(stun.BindingSuccess, stun.NewTransactionIDSetter(tID),
		stun.NewUsername("someusername"),
		stun.NewRealm("somerealm"),
		&stun.XORMappedAddress{IP: net.IPv4(213, 1, 223, 5), Port: 1234},
		stun.NewShortTermIntegrity("somepwd"),
		stun.Fingerprint,
	)
	b.ResetTimer()
	integrity := stun.NewShortTermIntegrity("somepwd")
	for i := 0; i < b.N; i++ {
		if err := integrity.Check(messageFull); err != nil {
			b.Fatal(err)
		}
	}
}

func BenchmarkAuthenticateLt(b *testing.B) {
	b.ReportAllocs()
	tID := stun.NewTransactionID()
	messageFull := stun.MustBuild(stun.BindingSuccess, stun.NewTransactionIDSetter(tID),
		stun.NewUsername("someusername"),
		stun.NewRealm("somerealm"),
		&stun.XORMappedAddress{IP: net.IPv4(213, 1, 223, 5), Port: 1234},
		stun.NewLongTermIntegrity("someusername", "somerealm", "somepwd"),
		stun.Fingerprint,
	)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		integrity := stun.NewLongTermIntegrity("someusername", "somerealm", "somepwd")
		if err := integrity.Check(messageFull); err != nil {
			b.Fatal(err)
		}
	}
}

func BenchmarkFingerprint(b *testing.B) {
	b.ReportAllocs()
	tID := stun.NewTransactionID()
	messageFull := stun.MustBuild(stun.BindingSuccess, stun.NewTransactionIDSetter(tID),
		stun.NewUsername("someusername"),
		stun.NewRealm("somerealm"),
		&stun.XORMappedAddress{IP: net.IPv4(213, 1, 223, 5), Port: 1234},
		stun.NewLongTermIntegrity("someusername", "somerealm", "somepwd"),
		stun.Fingerprint,
	)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if err := stun.Fingerprint.Check(messageFull); err != nil {
			b.Fatal(err)
		}
	}
}

// copied from pion
func BenchmarkErrorCode_AddTo(b *testing.B) {
	m := stun.New()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		stun.CodeStaleNonce.AddTo(m) //nolint:errcheck,gosec
		m.Reset()
	}
}

// copied from pion
func BenchmarkErrorCodeAttribute_GetFrom(b *testing.B) {
	m := stun.New()
	b.ReportAllocs()
	a := &stun.ErrorCodeAttribute{
		Code:   404,
		Reason: []byte("not found!"),
	}
	a.AddTo(m) //nolint:errcheck,gosec
	for i := 0; i < b.N; i++ {
		a.GetFrom(m) //nolint:errcheck,gosec
	}
}

func BenchmarkXORMappedAddress_AddTo(b *testing.B) {
	m := stun.New()
	b.ReportAllocs()
	ip := net.ParseIP("192.168.1.32")
	for i := 0; i < b.N; i++ {
		addr := &stun.XORMappedAddress{IP: ip, Port: 3654}
		addr.AddTo(m) //nolint:errcheck,gosec
		m.Reset()
	}
}

// this should fail! there is no tid
// func BenchmarkXORMappedAddress_GetFrom(b *testing.B) {
// 	m := stun.New()
// 	b.ReportAllocs()
// 	ip := net.ParseIP("192.168.1.32")
// 	addr := &stun.XORMappedAddress{IP: ip, Port: 3654}
// 	addr.AddTo(m)
// 	decodedAddr := new(stun.XORMappedAddress)
// 	b.ResetTimer()
// 	for i := 0; i < b.N; i++ {
// 		if err := decodedAddr.GetFrom(m); err != nil {
// 			b.Fatal(err)
// 		}
// 	}
// }

// copied from pion
func BenchmarkXORMappedAddress_GetFrom2(b *testing.B) {
	m := stun.New()
	transactionID, err := base64.StdEncoding.DecodeString("jxhBARZwX+rsC6er")
	if err != nil {
		b.Error(err)
	}
	copy(m.TransactionID[:], transactionID)
	addrValue, err := hex.DecodeString("00019cd5f49f38ae")
	if err != nil {
		b.Error(err)
	}
	m.Add(stun.AttrXORMappedAddress, addrValue)
	addr := new(stun.XORMappedAddress)
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		if err := addr.GetFrom(m); err != nil {
			b.Fatal(err)
		}
	}
}

func BenchmarkSoftware_AddTo(b *testing.B) {
	b.ReportAllocs()
	m := new(stun.Message)
	s := stun.Software("somesoftware")
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if err := s.AddTo(m); err != nil {
			b.Fatal(err)
		}
		m.Reset()
	}
}

func BenchmarkSoftware_GetFrom(b *testing.B) {
	b.ReportAllocs()
	m := stun.New()
	s := stun.Software("nonce")
	s.AddTo(m) //nolint:errcheck,gosec
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		s.GetFrom(m) //nolint:errcheck,gosec
	}
}

func BenchmarkTransactionID(b *testing.B) {
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		stun.NewTransactionID()
	}
}

// func BenchmarkMessage_NewTransactionID(b *testing.B) {
// 	b.ReportAllocs()
// 	m := new(stun.Message)
// 	m.WriteHeader()
// 	for i := 0; i < b.N; i++ {
// 		if err := m.NewTransactionID(); err != nil {
// 			b.Fatal(err)
// 		}
// 	}
// }

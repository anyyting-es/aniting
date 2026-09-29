package goja_bindings

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/sha256"
	"encoding/base64"
	"testing"

	"github.com/dop251/goja"
	gojabuffer "github.com/dop251/goja_nodejs/buffer"
	gojarequire "github.com/dop251/goja_nodejs/require"
	"github.com/stretchr/testify/require"
)

func TestGojaCryptoEncoders(t *testing.T) {
	vm := newCryptoTestVM(t)

	val, err := vm.RunString(`
        (() => ({
            bufferBase64: Buffer.from("Hello, this is a string to encode!").toString("base64"),
            bufferDecoded: Buffer.from("SGVsbG8sIHRoaXMgaXMgYSBzdHJpbmcgdG8gZW5jb2RlIQ==", "base64").toString("utf-8"),
            base64RoundTrip: CryptoJS.enc.Utf8.stringify(
                CryptoJS.enc.Base64.parse(
                    CryptoJS.enc.Base64.stringify(CryptoJS.enc.Utf8.parse("Hello, World!"))
                )
            ),
            latin1RoundTrip: CryptoJS.enc.Latin1.stringify(CryptoJS.enc.Latin1.parse("Hello, World!")),
            hexRoundTrip: CryptoJS.enc.Hex.stringify(CryptoJS.enc.Hex.parse("48656c6c6f2c20576f726c6421")),
            utf8RoundTrip: CryptoJS.enc.Utf8.stringify(CryptoJS.enc.Utf8.parse("𔭢")),
            utf16RoundTrip: CryptoJS.enc.Utf16.stringify(CryptoJS.enc.Utf16.parse("Hello, World!")),
            utf16LERoundTrip: CryptoJS.enc.Utf16LE.stringify(CryptoJS.enc.Utf16LE.parse("Hello, World!")),
        }))()
    `)
	require.NoError(t, err)

	obj := val.ToObject(vm)
	require.Equal(t, "SGVsbG8sIHRoaXMgaXMgYSBzdHJpbmcgdG8gZW5jb2RlIQ==", obj.Get("bufferBase64").String())
	require.Equal(t, "Hello, this is a string to encode!", obj.Get("bufferDecoded").String())
	require.Equal(t, "Hello, World!", obj.Get("base64RoundTrip").String())
	require.Equal(t, "Hello, World!", obj.Get("latin1RoundTrip").String())
	require.Equal(t, "48656c6c6f2c20576f726c6421", obj.Get("hexRoundTrip").String())
	require.Equal(t, "𔭢", obj.Get("utf8RoundTrip").String())
	require.Equal(t, "Hello, World!", obj.Get("utf16RoundTrip").String())
	require.Equal(t, "Hello, World!", obj.Get("utf16LERoundTrip").String())
}

func TestGojaCryptoAES(t *testing.T) {
	t.Run("random iv round trip", func(t *testing.T) {
		vm := newCryptoTestVM(t)

		val, err := vm.RunString(`
            (() => {
                const message = "seanime";
                const key = CryptoJS.enc.Utf8.parse("secret key");
                const encrypted = CryptoJS.AES.encrypt(message, key);
                return {
                    ciphertext: encrypted.toString(),
                    decrypted: CryptoJS.AES.decrypt(encrypted, key).toString(CryptoJS.enc.Utf8),
                };
            })()
        `)
		require.NoError(t, err)

		obj := val.ToObject(vm)
		ciphertext := obj.Get("ciphertext").String()
		decoded, err := base64.StdEncoding.DecodeString(ciphertext)
		require.NoError(t, err)
		require.Len(t, decoded, 32)
		require.Equal(t, "seanime", obj.Get("decrypted").String())
	})

	t.Run("fixed iv ciphertext is deterministic", func(t *testing.T) {
		vm := newCryptoTestVM(t)
		message := "seanime"
		key := []byte("secret key")
		iv := []byte("3134003223491201")

		val, err := vm.RunString(`
            (() => {
                const message = "seanime";
                const key = CryptoJS.enc.Utf8.parse("secret key");
                const iv = CryptoJS.enc.Utf8.parse("3134003223491201");
                const encrypted = CryptoJS.AES.encrypt(message, key, { iv });
                return {
                    ciphertext: encrypted.toString(),
                    ciphertextBase64: encrypted.toString(CryptoJS.enc.Base64),
                    decryptedWithIV: CryptoJS.AES.decrypt(encrypted, key, { iv }).toString(CryptoJS.enc.Utf8),
                    decryptedWithoutIV: CryptoJS.AES.decrypt(encrypted, key).toString(CryptoJS.enc.Utf8),
                };
            })()
        `)
		require.NoError(t, err)

		obj := val.ToObject(vm)
		expectedCiphertext := expectedAESCiphertext(message, key, iv)
		require.Equal(t, expectedCiphertext, obj.Get("ciphertext").String())
		require.Equal(t, expectedCiphertext, obj.Get("ciphertextBase64").String())
		require.Equal(t, message, obj.Get("decryptedWithIV").String())
		require.Empty(t, obj.Get("decryptedWithoutIV").String())
	})

	t.Run("invalid iv length returns an error string", func(t *testing.T) {
		vm := newCryptoTestVM(t)

		val, err := vm.RunString(`
            (() => {
                try {
                    CryptoJS.AES.encrypt("seanime", CryptoJS.enc.Utf8.parse("secret key"), {
                        iv: CryptoJS.enc.Utf8.parse("short"),
                    });
                    return "unexpected success";
                } catch (e) {
                    return String(e);
                }
            })()
        `)
		require.NoError(t, err)
		require.Contains(t, val.String(), "IV length must be equal to block size")
	})
}

func TestGojaCryptoOpenSSLDecrypt(t *testing.T) {
	vm := newCryptoTestVM(t)

	val, err := vm.RunString(`
        (() => {
            const payload = "U2FsdGVkX19ZanX9W5jQGgNGOIOBGxhY6gxa1EHnRi3yHL8Ml4cMmQeryf9p04N12VuOjiBas21AcU0Ypc4dB4AWOdc9Cn1wdA2DuQhryUonKYHwV/XXJ53DBn1OIqAvrIAxrN8S2j9Rk5z/F/peu1Kk/d3m82jiKvhTWQcxDeDW8UzCMZbbFnm4qJC3k19+PD5Pal5sBcVTGRXNCpvSSpYb56FcP9Xs+3DyBWhNUqJuO+Wwm3G1J5HhklxCWZ7tcn7TE5Y8d5ORND7t51Padrw4LgEOootqHtfHuBVX6EqlvJslXt0kFgcXJUIO+hw0q5SJ+tiS7o/2OShJ7BCk4XzfQmhFJdBJYGjQ8WPMHYzLuMzDkf6zk2+m7YQtUTXx8SVoLXFOt8gNZeD942snGrWA5+CdYveOfJ8Yv7owoOueMzzYqr5rzG7GVapVI0HzrA24LR4AjRDICqTsJEy6Yg==";
            const key = "6315b93606d60f48c964b67b14701f3848ef25af01296cf7e6a98c9460e1d2ac";
            return CryptoJS.AES.decrypt(payload, key).toString(CryptoJS.enc.Utf8);
        })()
    `)
	require.NoError(t, err)
	require.Equal(t, `[{"file":"https://cloudburst82.xyz/_v7/b39c8e03ac287e819418f1ad0644d7c0f506c2def541ec36e8253cd39f36c15ab46274b0ce5189dc51b2b970efa7b3abd9c70f52b02839d47a75863596d321a0b9c8b0370f96fa253d059244713458951d6c965d17a36ce87d4e2844d4665b7b658acd2318d5f8730643d893d2e1577307c767157b45abf64588a76b0cd8c1d2/master.m3u8","type":"hls"}]`, val.String())
}

func TestGojaCryptoErrorPaths(t *testing.T) {
	vm := newCryptoTestVM(t)

	tests := []struct {
		name   string
		script string
		want   string
	}{
		{
			name: "encrypt requires two arguments",
			script: `
				(() => {
					try {
						CryptoJS.AES.encrypt("only-message");
						return "unexpected success";
					} catch (e) {
						return String(e);
					}
				})()
			`,
			want: "AES.encrypt requires at least 2 arguments",
		},
		{
			name: "decrypt requires two arguments",
			script: `
				(() => {
					try {
						CryptoJS.AES.decrypt("ciphertext-only");
						return "unexpected success";
					} catch (e) {
						return String(e);
					}
				})()
			`,
			want: "AES.decrypt requires at least 2 arguments",
		},
		{
			name: "word array rejects invalid encoder",
			script: `
				(() => {
					try {
						CryptoJS.AES.encrypt("seanime", CryptoJS.enc.Utf8.parse("secret key")).toString("bad");
						return "unexpected success";
					} catch (e) {
						return String(e);
					}
				})()
			`,
			want: "encoder parameter must be a CryptoJS.enc object",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			val, err := vm.RunString(tt.script)
			require.NoError(t, err)
			require.Contains(t, val.String(), tt.want)
		})
	}
}

func TestGojaCryptoHelperCoverage(t *testing.T) {
	vm := goja.New()

	t.Run("adjust key length preserves valid sizes and hashes invalid sizes", func(t *testing.T) {
		key16 := []byte("1234567890abcdef")
		key24 := []byte("1234567890abcdefghijklmn")
		key32 := []byte("1234567890abcdefghijklmnopqrstuv")
		shortKey := []byte("short")

		require.Equal(t, key16, adjustKeyLength(key16))
		require.Equal(t, key24, adjustKeyLength(key24))
		require.Equal(t, key32, adjustKeyLength(key32))
		require.Len(t, adjustKeyLength(shortKey), 32)
		require.NotEqual(t, shortKey, adjustKeyLength(shortKey))
	})

	t.Run("low-level parser fallbacks", func(t *testing.T) {
		require.Nil(t, base64Parse("%%%"))
		require.Nil(t, hexParse("xyz"))
		require.Empty(t, utf16Stringify([]byte{0x00}))
		require.Empty(t, utf16LEStringify([]byte{0x00}))
	})

	t.Run("encoder wrappers handle undefined and wrong types", func(t *testing.T) {
		parseFns := []func(goja.FunctionCall) goja.Value{
			cryptoEncUtf8ParseFunc(vm),
			cryptoEncBase64ParseFunc(vm),
			cryptoEncHexParseFunc(vm),
			cryptoEncLatin1ParseFunc(vm),
			cryptoEncUtf16ParseFunc(vm),
			cryptoEncUtf16LEParseFunc(vm),
		}

		for _, parseFn := range parseFns {
			ret := parseFn(goja.FunctionCall{Arguments: []goja.Value{goja.Undefined()}})
			require.Equal(t, "", ret.String())
		}

		stringifyFns := []func(goja.FunctionCall) goja.Value{
			cryptoEncUtf8StringifyFunc(vm),
			cryptoEncBase64StringifyFunc(vm),
			cryptoEncHexStringifyFunc(vm),
			cryptoEncLatin1StringifyFunc(vm),
			cryptoEncUtf16StringifyFunc(vm),
			cryptoEncUtf16LEStringifyFunc(vm),
		}

		for _, stringifyFn := range stringifyFns {
			ret := stringifyFn(goja.FunctionCall{Arguments: []goja.Value{vm.ToValue("not-bytes")}})
			require.Equal(t, "", ret.String())
		}
	})
}

func newCryptoTestVM(t *testing.T) *goja.Runtime {
	t.Helper()

	vm := goja.New()
	t.Cleanup(vm.ClearInterrupt)

	registry := new(gojarequire.Registry)
	registry.Enable(vm)
	gojabuffer.Enable(vm)
	require.NoError(t, BindCrypto(vm))

	return vm
}

func expectedAESCiphertext(message string, key []byte, iv []byte) string {
	hash := sha256.Sum256(key)
	padded := pkcs7(message, aes.BlockSize)
	ciphertext := make([]byte, len(padded))

	block, err := aes.NewCipher(hash[:])
	if err != nil {
		panic(err)
	}

	cipher.NewCBCEncrypter(block, iv).CryptBlocks(ciphertext, padded)
	return base64.StdEncoding.EncodeToString(ciphertext)
}

func pkcs7(message string, blockSize int) []byte {
	data := []byte(message)
	padding := blockSize - len(data)%blockSize
	for i := 0; i < padding; i++ {
		data = append(data, byte(padding))
	}
	return data
}

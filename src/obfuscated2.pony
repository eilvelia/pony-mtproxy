use "crypto"
use "random"
use "time"
use "debug"
// use "buffered"

interface val Obfuscated2Encryptor
  new val create (obf_enc_key_bytes: Bytes)
  // fun obf (data: Bytes): Bytes iso^
  fun obf (data: Bytes): Bytes ref^

interface val Obfuscated2Decryptor
  new val create (obf_enc_key_bytes: Bytes)
  // fun deobf (data: Bytes): Bytes iso^
  fun deobf (data: Bytes): Bytes ref^

class val ClientDecryptor
  let _aes: Decrypt val

  new val create (secret: Bytes, obf_enc_key_bytes: Bytes) =>
    let key = SHA256(recover val
      let obf_enc_key = obf_enc_key_bytes.slice(8, 40)
      obf_enc_key.>concat(secret.values())
    end)

    let obf_enc_iv = recover val obf_enc_key_bytes.slice(40, 56) end

    _aes = recover val Decrypt.aes_ctr(key, obf_enc_iv) end

  fun deobf (data: Bytes): Bytes ref^ =>
    _aes.update(data)

class val ClientEncryptor
  let _aes: Encrypt val

  new val create (secret: Bytes, obf_enc_key_bytes: Bytes) =>
    let key_and_iv = recover val
      obf_enc_key_bytes.slice(8, 56).>reverse_in_place()
    end

    let key = SHA256(recover val
      let obf_enc_key = key_and_iv.slice(0, 32)
      obf_enc_key.>concat(secret.values())
    end)

    let obf_enc_iv = recover val key_and_iv.slice(32, 48) end

    _aes = recover val Encrypt.aes_ctr(key, obf_enc_iv) end

  fun obf (data: Bytes): Bytes ref^ =>
    _aes.update(data)

class ServerDecryptor is Obfuscated2Decryptor
  let _aes: Decrypt val

  new val create (obf_enc_key_bytes: Bytes) =>
    let key_and_iv = recover val
      obf_enc_key_bytes.slice(8, 56).>reverse_in_place()
    end

    let obf_enc_key = recover val key_and_iv.slice(0, 32) end
    let obf_enc_iv = recover val key_and_iv.slice(32, 48) end

    _aes = recover Decrypt.aes_ctr(obf_enc_key, obf_enc_iv) end

  fun deobf (data: Bytes): Bytes ref^ =>
    _aes.update(data)

class ServerEncryptor is Obfuscated2Encryptor
  let _aes: Encrypt val

  new val create (obf_enc_key_bytes: Bytes) =>
    let obf_enc_key = recover val obf_enc_key_bytes.slice(8, 40) end
    let obf_enc_iv = recover val obf_enc_key_bytes.slice(40, 56) end

    _aes = recover val Encrypt.aes_ctr(obf_enc_key, obf_enc_iv) end

  fun obf (data: Bytes): Bytes ref^ =>
    _aes.update(data)

class FakeDecryptor is Obfuscated2Decryptor
  new val create (obf_enc_key_bytes: Bytes) => None
  // new val none () => None
  fun deobf (data: Bytes): Bytes ref^ => data.clone()

class FakeEncryptor is Obfuscated2Encryptor
  new val create (obf_enc_key_bytes: Bytes) => None
  // new val none () => None
  fun obf (data: Bytes): Bytes ref^ => data.clone()

primitive Obfuscated2Util
  fun rand_bytes (intermediate: Bool = false): Bytes /* 64 bytes */ =>
    let seed = Time.now()._2.u64()
    let rand = Rand(seed)

    let random_buf = recover val
      let buf': Bytes ref = Bytes(64)
      buf'.undefined[U8](64)

      try
        while true do
          for i in buf'.keys() do
            buf'(i)? = rand.u8()
          end

          if buf'(0)? == 0xef then continue end

          let val2 = (buf'(7)?.u32() << 24)
            or (buf'(6)?.u32() << 16)
            or (buf'(5)?.u32() << 8)
            or (buf'(4)?.u32())

          if val2 == 0x00000000 then continue end

          let val1 = (buf'(3)?.u32() << 24)
            or (buf'(2)?.u32() << 16)
            or (buf'(1)?.u32() << 8)
            or (buf'(0)?.u32())

          if    (val1 != 0x44414548)
            and (val1 != 0x54534f50)
            and (val1 != 0x20544547)
            and (val1 != 0x4954504f)
            and ((val1 != 0xeeeeeeee) or (intermediate == true))
          then break end
        end

        if intermediate == true then
          buf'(56)? = 0xee
          buf'(57)? = 0xee
          buf'(58)? = 0xee
          buf'(59)? = 0xee
        else
          buf'(56)? = 0xef
          buf'(57)? = 0xef
          buf'(58)? = 0xef
          buf'(59)? = 0xef
        end
      end
      buf'
    end

    random_buf

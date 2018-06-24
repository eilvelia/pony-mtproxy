use "path:/usr/local/opt/libressl/lib" if osx
use "lib:crypto"

use @EVP_CIPHER_CTX_new[Pointer[_EVPCIPHERCTX] tag]()

use @EVP_aes_256_ctr[Pointer[_EVPCIPHER] tag]()

use @EVP_EncryptInit[ISize](
  ctx: Pointer[_EVPCIPHERCTX] tag,
  cipher: Pointer[_EVPCIPHER] tag,
  key: Pointer[U8] tag,
  iv: Pointer[U8] tag)

use @EVP_EncryptUpdate[ISize](
  ctx: Pointer[_EVPCIPHERCTX] tag,
  out: Pointer[U8] ref,
  // outl: Pointer[ISize] tag,
  outl: Pointer[USize] tag,
  inp: Pointer[U8] tag,
  // inl: ISize)
  inl: USize)

use @EVP_DecryptInit[ISize](
  ctx: Pointer[_EVPCIPHERCTX] tag,
  cipher: Pointer[_EVPCIPHER] tag,
  key: Pointer[U8] tag,
  iv: Pointer[U8] tag)

use @EVP_DecryptUpdate[ISize](
  ctx: Pointer[_EVPCIPHERCTX] tag,
  out: Pointer[U8] ref,
  // outl: Pointer[ISize] tag,
  outl: Pointer[USize] tag,
  inp: Pointer[U8] tag,
  // inl: ISize)
  inl: USize)

use @EVP_CIPHER_CTX_free[None](
  ctx: Pointer[_EVPCIPHERCTX] tag)

primitive _EVPCIPHERCTX
primitive _EVPCIPHER

class Encrypt
  let _ctx: Pointer[_EVPCIPHERCTX] tag
  // let _cipher: Pointer[_EVPCIPHER] tag

  new aes_ctr (key: ByteSeq box, iv: ByteSeq box) =>
    _ctx = @EVP_CIPHER_CTX_new()
    let cipher = @EVP_aes_256_ctr()
    @EVP_EncryptInit(_ctx, cipher, key.cpointer(), iv.cpointer())

  fun update (input: ByteSeq box): Bytes iso^ =>
    var size = input.size()
    recover
      let out: Pointer[U8] = @pony_alloc[Pointer[U8]](@pony_ctx(), size)
      @EVP_EncryptUpdate(_ctx, out, addressof size, input.cpointer(), size)
      Array[U8].from_cpointer(out, size)
    end

  fun _final () =>
    @EVP_CIPHER_CTX_free(_ctx)

class Decrypt
  let _ctx: Pointer[_EVPCIPHERCTX] tag
  // let _cipher: Pointer[_EVPCIPHER] tag

  new aes_ctr (key: ByteSeq box, iv: ByteSeq box) =>
    _ctx = @EVP_CIPHER_CTX_new()
    let cipher = @EVP_aes_256_ctr()
    @EVP_DecryptInit(_ctx, cipher, key.cpointer(), iv.cpointer())

  fun update (input: ByteSeq box): Bytes iso^ =>
    var size = input.size()
    recover
      let out: Pointer[U8] = @pony_alloc[Pointer[U8]](@pony_ctx(), size)
      @EVP_DecryptUpdate(_ctx, out, addressof size, input.cpointer(), size)
      Array[U8].from_cpointer(out, size)
    end

  fun _final () =>
    @EVP_CIPHER_CTX_free(_ctx)

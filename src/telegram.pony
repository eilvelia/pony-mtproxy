use net = "net"
use "collections"
use "debug"

type DcID is USize // 0 -- 4

class TelegramConnectionNotify is net.TCPConnectionNotify
  let _proxy: Proxy
  let _intermediate: Bool
  let _env: Env

  new iso create(proxy: Proxy, intermediate: Bool, env: Env) =>
    _proxy = proxy
    _intermediate = intermediate
    _env = env

  fun received(
    conn: net.TCPConnection ref,
    data: Array[U8] val,
    times: USize val
  ): Bool =>
    _proxy.received_server(data)
    true

  fun connected(conn: net.TCPConnection ref) =>
    // Debug("Telegram: " + _host + ":" + _port + " - Connected" +
    Debug("Telegram: Connected" +
      match _intermediate
      | true => " (intermediate)"
      else "" end)

    // conn.set_keepalive(7200)

    let random_buf = Obfuscated2Util.rand_bytes(_intermediate)

    let encryptor =
      if _intermediate == true then
        recover val ServerEncryptor(random_buf) end
      else
        recover val FakeEncryptor(random_buf) end
      end

    let decryptor =
      if _intermediate == true then
        recover val ServerDecryptor(random_buf) end
      else
        recover val FakeDecryptor(random_buf) end
      end

    let new_buf = recover val
      let buf_enc: Bytes ref = encryptor.obf(random_buf)
      for i in Range(0, 56) do
        try buf_enc(i)? = random_buf(i)? end
      end
      buf_enc
    end

    conn.write(new_buf)
    _proxy.server_ready(encryptor, decryptor)

  fun closed(conn: net.TCPConnection ref) =>
    _proxy.close_client_conn()
    Debug("Telegram connection closed")

  fun connect_failed(conn: net.TCPConnection ref) =>
    _proxy.close_client_conn()
    _env.out.print("Telegram: Connect failed")
    // Debug("err " + conn.get_so_error()._1.string() + " " + conn.get_so_error()._2.string())

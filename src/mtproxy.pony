use net = "net"
use "buffered"
use "time"
use "debug"

class TCPServerNotify is net.TCPListenNotify
  let _env: Env
  let _secret: Bytes
  let _timers: Timers = Timers
  let _stats_printer: StatsPrinter

  new iso create(env: Env, secret: String) =>
    _env = env
    _secret = Util.fromHex(secret)
    _stats_printer = StatsPrinter(env)

    let ns: U64 = Constants.stats_interval()
    _timers(Timer(StatsTimerNotify(_stats_printer), ns, ns))

  fun listening(listen: net.TCPListener ref) =>
    try
      (let host, let port) = listen.local_address().name()?
      _env.out.print("Listening on " + host + ":" + port)
      // Debug("Listening on " + host + ":" + port)
    else
      _env.out.print("Couldn't get local address")
      listen.close()
    end

  fun not_listening(listen: net.TCPListener ref) =>
    _env.out.print("Not listening")

  fun connected(listen: net.TCPListener ref): net.TCPConnectionNotify iso^ =>
    _stats_printer.inc()
    ClientConnectionNotify(_env, _secret)

class StatsTimerNotify is TimerNotify
  let _printer: StatsPrinter

  new iso create(printer: StatsPrinter) =>
    _printer = printer

  fun apply(timer: Timer, count: U64): Bool =>
    _printer.print()
    true

actor StatsPrinter
  let _env: Env
  var _total_conns: U64 = 0

  new create (env: Env) =>
    _env = env

  be inc () =>
    _total_conns = _total_conns + 1

  be print () =>
    _env.out.print("Total connections for all time: " + _total_conns.string())

actor Proxy
  let _env: Env
  let _secret: Bytes
  let _client_conn: net.TCPConnection tag
  var _initialized: Bool = false
  var _transport: (MtpTransportProtocol | None) = None
  var _server_connection: (net.TCPConnection tag | None) = None
  var _client_encryptor: (ClientEncryptor val | None) = None
  var _client_decryptor: (ClientDecryptor val | None) = None
  var _server_encryptor: (Obfuscated2Encryptor val | None) = None
  var _server_decryptor: (Obfuscated2Decryptor val | None) = None
  let _server_buffer: Array[Bytes] = Array[Bytes]

  new create (
    env: Env,
    secret: Bytes,
    client_conn: net.TCPConnection tag
  ) =>
    _env = env
    _secret = secret
    _client_conn = client_conn

  be server_ready (encryptor: Obfuscated2Encryptor, decryptor: Obfuscated2Decryptor) =>
    _server_encryptor = encryptor
    _server_decryptor = decryptor

    Debug("server_buffer packets " + _server_buffer.size().string())
    for packet in _server_buffer.values() do
      Debug("Send packet from buffer " + packet.size().string())
      _send_to_server(packet)
    end

  fun ref _create_new_connection (dc_id: DcID, intermediate: Bool = false) =>
    let port = Constants.telegram_port()

    try
      let host = Constants.telegram_servers()(dc_id)?._2

      _server_connection = net.TCPConnection(where
        auth = _env.root as AmbientAuth,
        notify = TelegramConnectionNotify(this, intermediate, _env),
        host = host,
        service = port,
        init_size = 10240,
        max_size = 65535)
    end

  be close_client_conn () =>
    _client_conn.dispose()

  be received_client (data: Bytes) =>
    Debug("client data size: " + data.size().string() +
      "  init: " + _initialized.string() + "  server_conn: " +
      match _server_connection
      | let x: net.TCPConnection => "yes"
      | None => "no"
      end)

    // Debug("From client")
    // Debug(data)

    if (data.size() < 64) and (_initialized == false) then
      _client_conn.dispose()
      return
    end

    let payload =
      if _initialized == true then
        data
      else
        _initialized = true
        if _initialize(data) == false then
          _client_conn.dispose()
        end
        recover val data.slice(64) end
      end

    try
      let decryptor = _client_decryptor as ClientDecryptor
      let dec_payload = recover val decryptor.deobf(payload) end

      Debug("dec_payload size " + dec_payload.size().string())

      // Debug("From client decrypted")
      // Debug(dec_payload)

      let data_to_send: Bytes =
        match _transport
        | let t: MtpTransportProtocol => t(dec_payload)
        else return end

      // Debug("data_to_send")
      // Debug(data_to_send)

      if data_to_send.size() > 0 then
        _send_to_server(data_to_send)
      end
    end

    Debug("\n--------\n")

  be received_server (data: Bytes val) =>
    try
      // Debug("From server")
      // Debug(data)
      // _env.out.print("From server ascii")
      // _env.out.print(data)

      let server_decryptor = _server_decryptor as Obfuscated2Decryptor
      let client_encryptor = _client_encryptor as ClientEncryptor

      let dec = recover val server_decryptor.deobf(data) end
      let enc = recover val client_encryptor.obf(dec) end

      // Debug("From server decrypted")
      // Debug(dec)
      // _env.out.print("From server decrypted ascii")
      // _env.out.print(dec)

      _client_conn.write(enc)
    else
      Debug("received_server error")
    end

  be client_closed () =>
    try (_server_connection as net.TCPConnection).dispose() end

  fun ref _send_to_server (data: Bytes) =>
    try
      let server_conn = _server_connection as net.TCPConnection
      let encryptor = _server_encryptor as Obfuscated2Encryptor

      let enc = recover val encryptor.obf(data) end
      server_conn.write(enc)
    else
      Debug("No server conn")
      _server_buffer.push(data)
    end

  fun ref _initialize (data: Bytes): Bool =>
    let obf_enc_key_bytes = recover val data.slice(0, 64) end

    let decryptor = ClientDecryptor(_secret, obf_enc_key_bytes)
    let encryptor = ClientEncryptor(_secret, obf_enc_key_bytes)

    let deobfed = recover val decryptor.deobf(obf_enc_key_bytes) end

    Debug("auth")
    Debug(deobfed)

    _client_decryptor = decryptor
    _client_encryptor = encryptor

    let reader = Reader
    reader.append(deobfed)

    try
      reader.skip(56)?

      let proto_tag = reader.u32_be()?

      Debug("tag: " + proto_tag.string())

      let mtp_transport: MtpTransportProtocol =
        match proto_tag
        | Constants.mtp_abridged() => MtpTcpAbridged
        | Constants.mtp_intermediate() | Constants.mtp_secure() => MtpTcpIntermediate
        else
          Debug("Unknown protocol")
          return false
        end

      _transport = mtp_transport

      let dc_id = USize.from[U16](reader.i16_le()?.abs() - 1)

      if dc_id > 4 then
        Debug("DcID invalid: " + dc_id.string())
        return false
      end

      Debug("DcID: " + (dc_id + 1).string())

      let intermediate =
        match mtp_transport
        | MtpTcpIntermediate => true
        else false end

      Debug("intermediate: " + intermediate.string())

      _create_new_connection(dc_id, intermediate)

      true
    else
      Debug("Unknown protocol: buffered.Reader error")
      false
    end

class ClientConnectionNotify is net.TCPConnectionNotify
  let _env: Env
  let _secret: Bytes
  var _host: String = "unknownhost"
  var _port: String = "unknownport"
  var _proxy: (Proxy | None) = None

  new iso create(env: Env, secret: Bytes) =>
    _env = env
    _secret = secret

  fun ref received(
    conn: net.TCPConnection ref,
    data: Array[U8] val,
    times: USize
  ): Bool =>
    try (_proxy as Proxy).received_client(data) end
    true

  fun ref accepted(conn: net.TCPConnection ref) =>
    try
      (_host, _port) = conn.remote_address().name()?
    end
    _proxy = Proxy(_env, _secret, conn)
    Debug("Client: " + _host + ":" + _port + " - Connected")

  fun closed(conn: net.TCPConnection ref) =>
    try (_proxy as Proxy).client_closed() end
    Debug("Client: " + _host + ":" + _port + " - Connection closed")

  fun connect_failed(conn: net.TCPConnection ref) =>
    Debug("Client: " + _host + ":" + _port + " - Connect failed")

  fun throttled(conn: net.TCPConnection ref) =>
    Debug("Client: throttled")

  fun unthrottled(conn: net.TCPConnection ref) =>
    Debug("Client: unthrottled")

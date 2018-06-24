use net = "net"
use "collections"
use "time"
use "debug"

type DcID is USize // 0 -- 4
type ConnectionID is U64
type ServerConnection is
  (
    ConnectionID,
    net.TCPConnection tag,
    Obfuscated2Encryptor val,
    Obfuscated2Decryptor val
  )
type ConnectionList is List[ServerConnection] ref
// type ConnectionsMap is Map[DcID, ConnectionList] ref

primitive PoolUtil
  fun create_connections_array(): Array[ConnectionList ref] iso^ =>
    let length = Constants.telegram_servers().size()
    recover
      let arr = Array[ConnectionList](length)
      for _ in Range(0, length) do
        arr.>push(ConnectionList)
      else arr end
    end

actor Pool
  let _env: Env
  let _timers: Timers = Timers
  let _closed_conns: Set[ConnectionID] = Set[ConnectionID]
  let _connected_conns: Array[ConnectionList] = PoolUtil.create_connections_array()
  var _conn_id: ConnectionID = 0
  var _client_conns_count: U64 = 0

  new create (env: Env) =>
    _env = env

    let min_idle_servers = Constants.min_idle_servers()

    for (dc_id, host) in Constants.telegram_servers().values() do
      for _ in Range[U32](0, min_idle_servers) do
        _create_new_connection(dc_id)
      end
    end

    let ns: U64 = Constants.stats_interval()
    _timers(Timer(StatsTimerNotify(this), ns, ns))

  be _create_new_connection (dc_id: DcID) =>
    let port = Constants.telegram_port()

    let id = _conn_id = _conn_id + 1 // (same as `let id = _conn_id++`)

    try
      let host = Constants.telegram_servers()(dc_id)?._2

      let conn = net.TCPConnection(where
        auth = _env.root as AmbientAuth,
        notify = TelegramIdleConnectionNotify(_env, host, port, id, dc_id, this),
        host = host,
        service = port,
        init_size = 10240,
        max_size = 65535)
    end

  fun ref _get_conn (dc_id: DcID): (ServerConnection | None) =>
    // let conns: List[net.TCPConnection] ref = _conns.get_or_else(dcID, List[net.TCPConnection])
    try
      let conns_list = _connected_conns(dc_id)?

      let tuple = for v in conns_list.values() do
        conns_list.shift()?
        let id = v._1
        if _closed_conns.contains(id) then
          _closed_conns.unset(id)
        else
          break v
        end
      end

      _create_new_connection(dc_id)?
      tuple
    end

  be get_conn (
    dc_id: DcID,
    proxy: Proxy
  ) =>
    _client_conns_count = _client_conns_count + 1

    try
      let conn_tuple = _get_conn(dc_id) as ServerConnection
      let conn = conn_tuple._2
      conn.set_notify(TelegramActiveConnectionNotify(proxy))
      proxy.set_server_conn(conn_tuple)
    else
      Debug("get_conn failed")
    end

  be reconnect_after (ns: U64, id: ConnectionID, dc_id: DcID) =>
    let timer = Timer(ReconnectTimerNotify(this, dc_id), ns)
    _timers(consume timer)

  be close_conn (id: ConnectionID) =>
    _closed_conns.set(id)

  be conn_connected (
    dc_id: DcID,
    id: ConnectionID,
    conn: net.TCPConnection tag,
    encryptor: Obfuscated2Encryptor val,
    decryptor: Obfuscated2Decryptor val
  ) =>
    try _connected_conns(dc_id)?.push(
      (id, conn, encryptor, decryptor)
    ) end

  be print_stats () =>
    var total_conns: USize = 0
    for conns_list in _connected_conns.values() do
      total_conns = total_conns + conns_list.size()
    end

    _env.out.print("Total connections for all time: " + _client_conns_count.string())
    Debug("Active and closed connections to telegram: " + total_conns.string())
    Debug("Closed connections to telegram: " + _closed_conns.size().string())

class ReconnectTimerNotify is TimerNotify
  let _pool: Pool
  let _dc_id: DcID

  new iso create(pool: Pool, dc_id: DcID) =>
    _pool = pool
    _dc_id = dc_id

  fun apply(timer: Timer, count: U64): Bool =>
    Debug("Reconnect!")
    _pool._create_new_connection(_dc_id)
    false

class StatsTimerNotify is TimerNotify
  let _pool: Pool

  new iso create(pool: Pool) =>
    _pool = pool

  fun apply(timer: Timer, count: U64): Bool =>
    _pool.print_stats()
    true

class TelegramActiveConnectionNotify is net.TCPConnectionNotify
  let _proxy: Proxy

  new iso create(proxy_instance: Proxy) =>
    _proxy = proxy_instance

  fun received(
    conn: net.TCPConnection ref,
    data: Array[U8] val,
    times: USize val
  ): Bool =>
    _proxy.received_server(data)
    true

  fun connect_failed(conn: net.TCPConnection ref) =>
    None

class TelegramIdleConnectionNotify is net.TCPConnectionNotify
  let _env: Env
  let _host: String
  let _port: String
  let _conn_id: ConnectionID
  let _dc_id: DcID
  let _pool: Pool

  new iso create(
    env: Env, host: String, port: String,
    id: ConnectionID, dc_id: DcID, pool: Pool
  ) =>
    _env = env
    _host = host
    _port = port
    _conn_id = id
    _dc_id = dc_id
    _pool = pool

  fun received(
    conn: net.TCPConnection ref,
    data: Array[U8] val,
    times: USize val
  ): Bool =>
    _env.out.print("Idle received:")
    _env.out.print(data)
    true

  fun connected(conn: net.TCPConnection ref) =>
    Debug("Telegram: " + _host + ":" + _port + " - Connected")
    conn.set_keepalive(7200)

    let random_buf = Obfuscated2Util.rand_bytes()

    // let encryptor = recover val ServerEncryptor(random_buf) end
    let encryptor = recover val FakeEncryptor(random_buf) end
    // let decryptor = recover val ServerDecryptor(random_buf) end
    let decryptor = recover val FakeDecryptor(random_buf) end

    let new_buf = recover val
      let buf_enc: Bytes ref = encryptor.obf(random_buf)
      for i in Range(0, 56) do
        try buf_enc(i)? = random_buf(i)? end
      end
      buf_enc
    end

    conn.write(new_buf)

    _pool.conn_connected(_dc_id, _conn_id, conn, encryptor, decryptor)

  fun closed(conn: net.TCPConnection ref) =>
    _pool.close_conn(_conn_id)
    _env.out.print("Telegram: " + _host + ":" + _port + " - Idle connection closed\n" +
      "Retrying in 3 seconds...")
    _pool.reconnect_after(3_000_000_000, _conn_id, _dc_id)

  fun connect_failed(conn: net.TCPConnection ref) =>
    _env.out.print("Telegram: " + _host + ":" + _port + " - Connect failed\n" +
      "Retrying in 3 seconds...")
    // Debug("err " + conn.get_so_error()._1.string() + " " + conn.get_so_error()._2.string())
    _pool.reconnect_after(3_000_000_000, _conn_id, _dc_id)

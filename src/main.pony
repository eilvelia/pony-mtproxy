use net = "net"
use "options"
use "debug"

type Port is String
type Secret is String

actor Main
  let _env: Env

  new create (env: Env) =>
    _env = env

    try
      (let port, let secret) = arguments()?
      start_server(port, secret)
    end

  fun usage () =>
    _env.out.print(
      """

      Usage: pony-mtproxy [options]

      Options:
        -p, --port    [string]  Defaults to '443'.
        -s, --secret  [string]
      """)

  fun arguments (): (Port, Secret) ? =>
    let options = Options(_env.args)

    options
      .add("port", "p", StringArgument)
      .add("secret", "s", StringArgument, Required)

    var port: Port = "443"
    var secret: (Secret | None) = None

    for option in options do
      match option
      | ("port", let arg: String) => port = arg
      | ("secret", let arg: String) => secret = arg
      | let err: ParseError =>
          err.report(_env.out)
          usage()
          error
      end
    end

    try
      (port, secret as Secret)
    else
      _env.out.print("Secret is not specified.")
      usage()
      error
    end

  fun start_server (port: String, secret: String) =>
    try
      net.TCPListener(where
        auth = _env.root as AmbientAuth,
        notify = TCPServerNotify(_env, secret),
        host = "",
        service = port,
        init_size = 10240,
        max_size = 65535)
    else
      _env.out.print("Internal error")
    end

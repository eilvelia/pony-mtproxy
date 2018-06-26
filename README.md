# pony-mtproxy

Yet another Telegram MTProto Proxy server.

wip

## Usage

```console
$ pony-mtproxy [options]
```

Options:

```
  -p, --port    [string]  Defaults to '443'.
  -s, --secret  [string]
```

Example:

```console
$ pony-mtproxy --secret 15abcdef1234567890deadbeef123456
```

---

Link example: `tg://proxy?server=SERVER_IP&port=PORT&secret=SECRET`

## Building

```sh
git clone https://github.com/Bannerets/pony-mtproxy pony-mtproxy
cd pony-mtproxy
ponyc src -b pony-mtproxy
```

Requirements:

- `ponyc`

## Docker

```console
$ docker run --name mtproxy -d --restart unless-stopped -p 443:443 bannerets/pony-mtproxy:latest --secret 15abcdef1234567890deadbeef123456
```

#### Logs

```console
$ docker logs mtproxy
```

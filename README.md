# pony-mtproxy

Yet another Telegram MTProto Proxy server.

wip

- Crossplatform.
- Multithreaded.
- No promoted channels support.
- No multi secret support.

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

Link example: `tg://proxy?server={SERVER_IP}&port={PORT}&secret={SECRET}`

Link with secure mode: `tg://proxy?server={SERVER_IP}&port={PORT}&secret=dd{SECRET}`

## Building

```sh
git clone https://github.com/Bannerets/pony-mtproxy pony-mtproxy
cd pony-mtproxy
ponyc src -b pony-mtproxy
```

Requirements:

- `ponyc`
- `openssl`

## Docker

```console
$ docker run --name mtproxy -d --restart unless-stopped -p 443:443 bannerets/pony-mtproxy:latest --secret 15abcdef1234567890deadbeef123456
```

#### Logs

```console
$ docker logs mtproxy
```

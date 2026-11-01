import os
import socket
import sys

PROXY_HOST = os.environ.get("PWF_PROXY_HOST", "172.30.32.1")
PROXY_PORT = int(os.environ.get("PWF_PROXY_PORT", "15537"))


def main():
    if len(sys.argv) < 3:
        sys.exit("usage: proxyconnect.py <host> <port>")
    host, port = sys.argv[1], int(sys.argv[2])

    s = socket.create_connection((PROXY_HOST, PROXY_PORT), timeout=30)
    req = (
        "CONNECT %s:%d HTTP/1.1\r\nHost: %s:%d\r\n"
        "Proxy-Connection: keep-alive\r\n\r\n" % (host, port, host, port)
    )
    s.sendall(req.encode())

    buf = b""
    while b"\r\n\r\n" not in buf:
        d = s.recv(4096)
        if not d:
            sys.exit("proxy closed during handshake")
        buf += d
    head, rest = buf.split(b"\r\n\r\n", 1)
    status = head.split(b"\r\n")[0]
    if b" 200" not in status:
        sys.exit("proxy refused: " + status.decode("latin1", "replace"))

    out = sys.stdout.buffer
    if rest:
        out.write(rest)
        out.flush()

    import threading

    def upstream_to_stdout():
        while True:
            try:
                d = s.recv(65536)
            except Exception:
                break
            if not d:
                break
            out.write(d)
            out.flush()
        os._exit(0)

    threading.Thread(target=upstream_to_stdout, daemon=True).start()

    while True:
        try:
            d = os.read(0, 65536)
        except Exception:
            break
        if not d:
            break
        s.sendall(d)


if __name__ == "__main__":
    main()

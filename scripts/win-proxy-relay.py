"""把 Windows 上仅监听 127.0.0.1 的代理端口暴露给 WSL（NAT 网关侧）。

监听 0.0.0.0:15537，纯 TCP 转发到 127.0.0.1:55376。
不解析协议，CONNECT 隧道原样透传。
"""
import socket
import threading

LISTEN = ("0.0.0.0", 15537)
UPSTREAM = ("127.0.0.1", 7897)   # Clash/mihomo mixed port；55376 为失效的沙箱代理


def pipe(src, dst):
    try:
        while True:
            data = src.recv(65536)
            if not data:
                break
            dst.sendall(data)
    except Exception:
        pass
    finally:
        try:
            dst.shutdown(socket.SHUT_WR)
        except Exception:
            pass


def handle(client):
    try:
        up = socket.create_connection(UPSTREAM, timeout=30)
    except Exception:
        try:
            client.close()
        except Exception:
            pass
        return
    threading.Thread(target=pipe, args=(client, up), daemon=True).start()
    threading.Thread(target=pipe, args=(up, client), daemon=True).start()


def main():
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(LISTEN)
    srv.listen(128)
    print("relay listening on %s:%d -> %s:%d" % (LISTEN + UPSTREAM), flush=True)
    while True:
        try:
            client, _ = srv.accept()
        except Exception:
            continue
        handle(client)


if __name__ == "__main__":
    main()

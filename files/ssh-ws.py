#!/usr/bin/env python3
# SSH over WebSocket -> OpenSSH :22 (dipanggil nginx di 127.0.0.1:10015)
import asyncio
LISTEN = ("127.0.0.1", 10015)
TARGET = ("127.0.0.1", 22)

async def pipe(r, w):
    try:
        while True:
            d = await r.read(65536)
            if not d:
                break
            w.write(d); await w.drain()
    except Exception:
        pass
    finally:
        try: w.close()
        except Exception: pass

async def handle(cr, cw):
    try:
        await cr.readuntil(b"\r\n\r\n")
        cw.write(b"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n")
        await cw.drain()
        tr, tw = await asyncio.open_connection(*TARGET)
    except Exception:
        cw.close(); return
    await asyncio.gather(pipe(cr, tw), pipe(tr, cw))

async def main():
    s = await asyncio.start_server(handle, *LISTEN)
    async with s:
        await s.serve_forever()

asyncio.run(main())

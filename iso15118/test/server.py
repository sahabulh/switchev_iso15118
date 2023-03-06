import asyncio
import datetime
import ssl

async def handle_echo(reader, writer):
    i = 0
    while (i < 10):
        data = await reader.read(100)
        dt = datetime.datetime.now()
        message = data.decode()
        addr = writer.get_extra_info('peername')

        print(f"Time: {dt} Received {message!r} from {addr!r}")

        dt = datetime.datetime.now()
        print(f"Time: {dt} Send: {message!r}")
        writer.write(data)
        await writer.drain()
        if message == "quit":
            break
        i = i + 1
        await asyncio.sleep(2)

    print("Close the connection")
    writer.close()
    await writer.wait_closed()
    
async def main():
    ctx = ssl.SSLContext(protocol=ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain('cpoCertChain.pem', keyfile='seccLeaf.key', password='12345')
    ctx.load_verify_locations(cafile='oemRootCACert.pem')
    ctx.check_hostname = False
    ctx.verify_mode = ssl.VerifyMode.CERT_REQUIRED
    ctx.set_ciphers('ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384')
    server = await asyncio.start_server(
        handle_echo, '127.0.0.1', 9002, ssl=ctx)

    addrs = ', '.join(str(sock.getsockname()) for sock in server.sockets)
    print(f'Serving on {addrs}')

    async with server:
        await server.serve_forever()
        
asyncio.run(main())

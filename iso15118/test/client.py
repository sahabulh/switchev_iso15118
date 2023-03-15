import asyncio
import datetime
import ssl

class Dummy():
    def __init__(self, value):
        self.value = value
    
    def print():
        print("Dummy value: " + str(self.value))

async def tcp_echo_client(message):
    ctx = ssl.SSLContext(protocol=ssl.PROTOCOL_TLS_CLIENT)
    ctx.load_cert_chain('oemCertChain.pem', 'oemLeaf.key', '12345')
    ctx.load_verify_locations(cafile='v2gRootCACert.pem')
    ctx.check_hostname = False
    ctx.verify_mode = ssl.VerifyMode.CERT_REQUIRED
    ctx.set_ciphers('ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384')
    reader, writer = await asyncio.open_connection(
        '127.0.0.1', 9002, ssl=ctx)
    
    i = 0
    while (i < 5):
        dt = datetime.datetime.now()
        print(f'Time: {dt} Send: {message!r}')
        writer.write(message.encode())
        await writer.drain()

        
        data = await reader.read(100)
        dt = datetime.datetime.now()
        print(f'Time: {dt} Received: {data.decode()!r}')
        i = i + 1
        await asyncio.sleep(1)
    
    message = 'quit'
    print(f'Send: {message!r}')
    writer.write(message.encode())
    await writer.drain()
    data = await reader.read(100)
    print(f'Received: {data.decode()!r}')
        
    print('Close the connection')
    writer.close()
    await writer.wait_closed()
    
asyncio.run(tcp_echo_client("Hello!"))

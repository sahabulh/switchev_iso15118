def get_generator(pad, offset):
    num = 1 + offset
    while True:
        out = format(num, 'x').upper()
        yield out.zfill(pad)
        num += 1

def get_EMAID(offset = 0):
    # Used in the contract certificate (ISO 15118-20 C.1 and ISO 15118-2 H.1)
    # For now, country code 'US', Provider ID 'EMA' and ID type 'C', are hard coded
    # eMA Instance: at least 8 character
    gen = get_generator(8, offset)
    while True:
        yield 'USEMAC'+next(gen)

def get_PCID(offset = 0):
    # Used in the OEM provisioning certificate (ISO 15118-20 C.2)
    # For now, WMI code '1EV', ID type 'P', are hard coded
    # OEM's own unique ID: at least 13 character
    gen = get_generator(13, offset)
    while True:
        yield '1EVP'+next(gen)

def get_SECCID(offset = 0):
    # Used in the SECC certificate (ISO 15118-20 C.3)
    # For now, country code 'US', EVSE Operator ID '2SE' and ID type 'S', are hard coded
    # Controller ID: at least 32 character
    gen = get_generator(32, offset)
    while True:
        yield 'US2SES'+next(gen)

def get_EVSEID(offset = 0):
    # Used for EVSE identification (ISO 15118-20 C.4 and ISO 15118-2 H.2)
    # For now, country code 'US', EVSE Operator ID '2SE' and ID type 'E', are hard coded
    # Power Outlet ID: 1 to 31 character(s). We will use 9 characters. 
    gen = get_generator(9, offset)
    while True:
        yield 'US2SEE'+next(gen)

def get_EVCCID(offset = 0):
    # Used in the EVCC or EV device certificate (ISO 15118-20 C.5)
    # For now, WMI code '1EV', ID type 'V', are hard coded
    # Power Outlet ID: 1 to 31 character(s). We will use 9 characters. 
    gen = get_generator(9, offset)
    while True:
        yield '1EVV'+next(gen)

def example(id_type, num):
    # Usage: example('emaid',10)
    if id_type == 'emaid':
        gen_id = get_EMAID()
    elif id_type == 'pcid':
        gen_id = get_PCID()
    elif id_type == 'seccid':
        gen_id = get_SECCID()
    elif id_type == 'evccid':
        gen_id = get_EVCCID()
    elif id_type == 'evseid':
        gen_id = get_EVSEID()
    for i in range(num):
        print(next(gen_id))
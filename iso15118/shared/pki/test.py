import os
from cryptography import x509
ISO_FOLDER = "iso15118_20/"
with open(ISO_FOLDER+"certs/contractLeafCert.pem", "rb") as f:
    cert = x509.load_pem_x509_certificate(f.read())
    serial_number = format(cert.serial_number, 'x').upper()
    os.rename("key_vault/"+ISO_FOLDER+"a.key", "key_vault/"+ISO_FOLDER+"_"+serial_number+".kay")
    print(serial_number)
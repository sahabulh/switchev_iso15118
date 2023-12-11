import requests

from gen_ids import get_EMAID

from cryptography.hazmat.primitives import serialization
from cryptography import x509

emaid = get_EMAID()
headers = {'accept': 'application/json', 'X-API-KEY': '014f43b1b6a27650c00298f226_696e1e0a8be2a219d251e0661ad2e8f4e87d42fc42ab4bab5a1acefb283af355', 'Content-Type': 'application/json'}

def get_certChain(serial):
    data = {"serial_number": serial}
    res = requests.get('https://demo.one.digicert.com/iot/api/v1/certificate/', headers=headers, params=data)
    data = res.json()
    if len(data['records']):
        certs = []
        certs.append(x509.load_pem_x509_certificate(data['records'][0]['body'].encode()))
        for cert in data['records'][0]['chain']:
            certs.append(x509.load_pem_x509_certificate(cert['blob'].encode()))
        return certs
    else:
        raise Exception(f"Certificate with serial {serial} couldn't be found.")
        
def save_certs(certs, encoding = 'all'):
    folder = "iso15118_20/certs/"
    num_certs = len(certs)
    for i in range(num_certs):
        if i == 0:
            name = "contractLeafCert"
        elif i == 1:
            name = "moSubCA2Cert"
        elif i == 2 and num_certs == 4:
            name = "moSubCA1Cert"
        elif (i == 3) or (i == 2 and num_certs == 3):
            name = "moRootCACert"
        else:
            raise Exception(f"Chain contains {num_certs} certificates. Should contain 3 or 4.")
        if encoding == 'all' or encoding == 'pem':
            with open(folder+name+".pem", "wb") as outfile:
                outfile.write(certs[i].public_bytes(serialization.Encoding.PEM))
        if encoding == 'all' or encoding == 'der':
            with open(folder+name+".der", "wb") as outfile:
                outfile.write(certs[i].public_bytes(serialization.Encoding.DER))
        
def download_certs(serial, encoding = 'all'):
    certs = get_certChain(serial)
    save_certs(certs, encoding = encoding)
    
download_certs('76F8365B420D67AEB3F7E8AC00E0BB844E54D7FE')
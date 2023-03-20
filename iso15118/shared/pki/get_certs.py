import os
import shutil
import requests
import argparse

from gen_ids import get_EMAID

from cryptography.hazmat.primitives import serialization
from cryptography import x509

folder = None
emaid = get_EMAID()
headers = {'accept': 'application/json', 'X-API-KEY': '014f43b1b6a27650c00298f226_696e1e0a8be2a219d251e0661ad2e8f4e87d42fc42ab4bab5a1acefb283af355', 'Content-Type': 'application/json'}

# Handle arguments
parser = argparse.ArgumentParser()
parser.add_argument("-l", "--list", help = "Lists the MO certificates.", action="store_true")
parser.add_argument("-s", "--serial", type=str, help = "Download the certificate by matchig the exact serial number.")
parser.add_argument("-p", "--protocol", choices = ['iso-2','iso-20'], type=str, help = "Specify ISO15118 protocol. Use 'iso-2' for ISO15118-2 and 'iso-20' for ISO15118-20.")
args = parser.parse_args()

def list_certs(cert_type = "contract", status = "ISSUED", offset = 0, limit = 20, disp = True):
    """
    Lists (if "disp" is ture) DigiCert ONE certificates matching supplied parameters. Serial number and Common name of the first matched certifiate are returned.

    Parameters
    ----------
    cert_type : str, optional
        Certificate type. Choices are "contract" and "secc". The default is "contract".
    status : str, optional
        Certificate status. Choices are "ISSUED", "REVOKED" and "EXPIRED". The default is "ISSUED".
    offset : int, optional
        The first offset number(s) of certificates will not be listed. The default is 0.
    limit : int, optional
        Limits the number of certificates in the list. The default is 20.
    disp : bool, optional
        Enables or diables list printing.

    Returns
    -------
    [str, str] or None
        Serial number and Common name of the first matched certifiate are returned as a list. 'None' is returned in case of no match.
    """
    if cert_type == "contract":
        enrollment_profile_id = "IOT_79f09602-de08-4355-a265-08a581d84143"
    elif cert_type == "secc":
        enrollment_profile_id = "IOT_f2286f88-4cfa-4d99-be24-998dd1a10e60"
    else:
        print("Wrong certificate type. It should be either 'contract' or 'secc'.")
        return None
    
    data = {"enrollment_method": "API",
        "enrollment_profile_id": enrollment_profile_id,
        "certificate_type": "x509",
        "offset": offset,
        "limit": limit
    }
    if status in ["ISSUED","REVOKED","EXPIRED"]:
        data["status"] = status
    r = requests.get('https://demo.one.digicert.com/iot/api/v1/certificate/', headers=headers, params=data)
    d = r.json()
    if len(d['records']):
        if disp:
            print(f"List of {status.lower()} {cert_type} certificate(s):")
            for i in range(len(d['records'])):
                print(f"Cert {i+1+offset}, CN: {d['records'][i]['common_name']}, Serial: {d['records'][i]['serial_number']}, Status: {d['records'][i]['status']}")
        return [d['records'][0]['serial_number'],d['records'][0]['common_name']]
    else:
        if disp:
            print("No matching records found.")
        return None

def get_certChain(serial):
    data = {"serial_number": serial}
    res = requests.get('https://demo.one.digicert.com/iot/api/v1/certificate/', headers=headers, params=data)
    data = res.json()
    if len(data['records']):
        global folder
        certs = []
        certs.append(x509.load_pem_x509_certificate(data['records'][0]['body'].encode()))
        key_file_name = data['records'][0]['common_name']+"_"+serial+".key"
        cwd = os.getcwd()
        if os.path.exists(cwd+"/key_vault/iso15118_2/"+key_file_name):
            folder = "iso15118_2/certs/"
            shutil.copy(cwd+"/key_vault/iso15118_2/"+key_file_name,cwd+"/iso15118_2/private_keys/contractLeaf.key")
        elif os.path.exists(cwd+"/key_vault/iso15118_20/"+key_file_name):
            folder = "iso15118_20/certs/"
            shutil.copy(cwd+"/key_vault/iso15118_20/"+key_file_name,cwd+"/iso15118_20/private_keys/contractLeaf.key")
        else:
            raise Exception(f"FileNotFound: {key_file_name} not found in the key vault.")
        for cert in data['records'][0]['chain']:
            certs.append(x509.load_pem_x509_certificate(cert['blob'].encode()))
        return certs
    else:
        raise Exception(f"Certificate with serial {serial} couldn't be found.")

def save_certs(certs, encoding = 'all'):
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


if args.serial:
    download_certs(args.serial)
else:
    if args.protocol == "iso-2":
        download_certs('76F8365B420D67AEB3F7E8AC00E0BB844E54D7FE')
    else:
        # Default if protocol isn't specified.
        download_certs('10872D45E2B2436D331C90BDEBB8337E3C6874CC')
        
if args.list:
    list_certs()
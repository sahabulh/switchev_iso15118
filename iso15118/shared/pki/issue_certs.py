import os
import json
import requests
import argparse
import subprocess

from gen_ids import get_EMAID

from cryptography import x509

headers = {'accept': 'application/json', 'X-API-KEY': '014f43b1b6a27650c00298f226_696e1e0a8be2a219d251e0661ad2e8f4e87d42fc42ab4bab5a1acefb283af355', 'Content-Type': 'application/json'}

# Handle arguments
parser = argparse.ArgumentParser()
parser.add_argument("-i", "--issue", help = "Enables certificate issuance.", action="store_true")
parser.add_argument("-l", "--list", help = "Lists all the issued MO certificates.", action="store_true")
parser.add_argument("-p", "--protocol", choices = ['iso-2','iso-20'], type=str, help = "Specify ISO15118 protocol. Use 'iso-2' for ISO15118-2 and 'iso-20' for ISO15118-20.")
args = parser.parse_args()

def list_certs(cert_type = "contract", status = "ISSUED", offset = 0, limit = 20):
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
    print(f"List of {status.lower()} {cert_type} certificate(s):")
    if len(d['records']):
        for i in range(len(d['records'])):
            print(f"Cert {i+1+offset}, CN: {d['records'][i]['common_name']}, Serial: {d['records'][i]['serial_number']}, Status: {d['records'][i]['status']}")
    else:
        print("No matching records found.")

def issue_certs(cert_protocol, offset = 0):
    emaid = get_next_available_emaid(offset)
    if cert_protocol == 2:
        ISO_FOLDER = "iso15118_2/"
        res = subprocess.run("./create_csr.sh -e "+emaid+" -v iso-2", shell=True)
    elif cert_protocol == 20:
        ISO_FOLDER = "iso15118_20/"
        res = subprocess.run("./create_csr.sh -e "+emaid+" -v iso-20", shell=True)
    else:
        raise Exception("Invalid protocol!")
    with open(ISO_FOLDER+"csrs/"+emaid+".csr", "r") as f:
        csr = f.read()
        data = {"csr": csr, "enrollment_profile_id": "IOT_79f09602-de08-4355-a265-08a581d84143"}
        res = requests.post('https://demo.one.digicert.com/iot/api/v1/certificate/', headers=headers, data=json.dumps(data))
        data = res.json()
        if data['result'] == 'SUCCESS':
            certs = x509.load_pem_x509_certificates(data['pem'].encode())
            serial_number = format(certs[0].serial_number, 'x').upper()
            os.rename("key_vault/"+ISO_FOLDER+emaid+".key", "key_vault/"+ISO_FOLDER+emaid+"_"+serial_number+".key")
            return certs
        else:
            raise Exception("Certificate issue request is not successful.")
    return None

def get_next_available_emaid(offset = 0):
    gen_emaid = get_EMAID(offset)
    emaid = next(gen_emaid)
    while isUnavailable(emaid):
        emaid = next(gen_emaid)
    print(f"Next available EMAID: {emaid}")
    return emaid

def isUnavailable(emaid, status = "ISSUED"):
    data = {"common_name": emaid, "status": status}
    res = requests.get('https://demo.one.digicert.com/iot/api/v1/certificate/', headers=headers, params=data)
    data = res.json()
    if len(data['records']):
        return True
    return False

if args.issue:
    print(f"Selected protocol: '{args.protocol}'")
    if args.protocol == 'iso-2':
        issue_certs(2)
    elif args.protocol == 'iso-20':
        issue_certs(20)
        
if args.list:
    list_certs()
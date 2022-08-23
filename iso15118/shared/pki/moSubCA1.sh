#!/bin/bash

VALIDITY_MO_SUBCA1_CERT=1460

ISO_2="iso-2"
ISO_20="iso-20"

usage() {
  echo "
  Usage: "$0" [-h] [-v <iso-2|iso-20>] [-p password] [-k]

  Options:
   -h --help          Returns this helper
   -v --version       ISO version to run the script for: 'iso-2' refers to ISO 15118-2,
                      whereas 'iso-20' refers to ISO 15118-20
   -p --password      The password to encrypt and decrypt the private keys
   -k --keysight      Generate certificates to be used while pairing with Keysight test system,
                      alongside this iso15118 project.


  Description:
    You can use this script to create all the private keys and public key certificates
    necessary to run an ISO 15118 Plug & Charge session (for testing purposes only).
    You need to provide the ISO 15118 version with the '-v' flag, choosing between the
    two admissible options stated above.

    This script uses by default a password value of 12345, which can be modified
    if -p option is used as exemplified above.

    NOTE: This script will create the following folder structure, if not already
    existing, depending on the protocol version you choose and place the corresponding
    private keys, certificate signing requests (csrs), and certificates (certs) in the
    right folder, overwriting any files with the same name:

    |__ iso15118_2 (or iso15118_20)
      |__ certs
      |__ csrs
      |__ private_keys
  "
  exit 0;
}

validate_option() {
    # Check if the version provided is valid, if not it returns
    if [ "$1" != $ISO_2 ] && [ "$1" != $ISO_20 ]; then
        echo "The version provided is invalid"
        usage
    fi
}


if [ -z $1 ]; then echo "No options were provided"; usage; fi

while [ -n "$1" ]; do
    case "$1" in
        -h|--help)
            usage
            ;;
        -v|--version)
            validate_option $2
            version=$2
            shift  # params with args need an extra shift
            ;;
        -p|--password)
            password=$2
            shift
            ;;
        -k|--keysight)
            keysight_certs="1"
            ;;
         *)
            echo "Unknown option $1"
            usage
            ;;
    esac
    shift
done


# Set the cryptographic parameters, depending on whether to create certificates and key
# material for ISO 15118-2 or ISO 15118-20

if [ $version == $ISO_2 ];
then
    ISO_FOLDER=iso15118_2
    SYMMETRIC_CIPHER=-aes-128-cbc
    SYMMETRIC_CIPHER_PKCS12=-aes128
    SHA=-sha256
    # Note: OpenSSL does not use the named curve 'secp256r1' (as stated in
    # ISO 15118-2) but the equivalent 'prime256v1'
    EC_CURVE=prime256v1
else
    ISO_FOLDER=iso15118_20
    SYMMETRIC_CIPHER=-aes-256-cbc  # TODO Check correct version for ISO 15118-20
    SYMMETRIC_CIPHER_PKCS12=-aes128  # TODO Check correct version for ISO 15118-20
    SHA=-sha256  # TODO Check correct version for ISO 15118-20
    EC_CURVE=ED448  # TODO Check correct version for ISO 15118-20
    # TODO: Also enable cipher suite TLS_CHACHA20_POLY1305_SHA256
fi

# The password used to encrypt (and decrypt) private keys
# Security note: this is for testing purposes only!
if [ -z $password ]; then
    password=12345
fi

echo "Password used is: '$password'"

# Create directories if not yet existing
CERT_PATH=$ISO_FOLDER/certs
KEY_PATH=$ISO_FOLDER/private_keys
CSR_PATH=$ISO_FOLDER/csrs
mkdir -p $CERT_PATH
mkdir -p $CSR_PATH
mkdir -p $KEY_PATH

# Create an intermediate MO sub-CA 1 certificate which is directly signed by the MORootCA certificate

# Generate private key
if [ $version == $ISO_2 ];
then
    openssl ecparam -genkey -name $EC_CURVE | openssl ec $SYMMETRIC_CIPHER -passout pass:$password -out $KEY_PATH/moSubCA1.key
else
    openssl genpkey -algorithm $EC_CURVE $SYMMETRIC_CIPHER -pass pass:$password -out $KEY_PATH/moSubCA1.key
fi

# Create a CSR
openssl req -new -key $KEY_PATH/moSubCA1.key -passin pass:$password -config configs/moSubCA1Cert.cnf -out $CSR_PATH/moSubCA1.csr
echo "CSR generation is done."

DEST=/venv/lib/python3.10/site-packages/iso15118/shared/pki/
ssh -o 'StrictHostKeyChecking no' root@10.1.2.105 "cd $DEST;mkdir -p $CERT_PATH;mkdir -p $CSR_PATH;mkdir -p $KEY_PATH"
scp $CSR_PATH/moSubCA1.csr root@10.1.2.105:$DEST$CSR_PATH
echo "CSR is sent to the MORootCA."

# Create an X.509 certificate 
ssh root@10.1.2.105 "cd $DEST;openssl x509 -req -in $CSR_PATH/moSubCA1.csr -extfile configs/moSubCA1Cert.cnf -extensions ext -CA $CERT_PATH/moRootCACert.pem -CAkey $KEY_PATH/moRootCA.key -passin pass:$password -set_serial 12354 -out $CERT_PATH/moSubCA1Cert.pem -days $VALIDITY_MO_SUBCA1_CERT"
echo "Certificate generation and signing is finished."
ssh root@10.1.2.105 "cd $DEST;rm $CSR_PATH/moSubCA1.csr"
echo "CSR is deleted from the MORootCA."

ssh root@10.1.2.105 "cd $DEST;scp -o 'StrictHostKeyChecking no' $CERT_PATH/moSubCA1Cert.pem root@10.1.2.106:$DEST$CERT_PATH"
echo "Certificate is sent back to the MO sub-CA 1."
ssh root@10.1.2.105 "cd $DEST;rm $CERT_PATH/moSubCA1Cert.pem"
echo "Certificate is deleted from the MORootCA."

# Convert the certificates from PEM format to DER format
openssl x509 -inform PEM -in $CERT_PATH/moSubCA1Cert.pem -outform DER -out $CERT_PATH/moSubCA1Cert.der
echo "Certificate has been converted and saved in DER format."

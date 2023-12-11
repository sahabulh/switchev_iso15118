#!/bin/bash

VALIDITY_CONTRACT_LEAF_CERT=730
HOST="Contract leaf"
MASTER="MO Sub-CA 2"

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

# Create a contract leaf certificate which is directly signed by MO sub-CA 2

# Generate private key
if [ $version == $ISO_2 ];
then
    openssl ecparam -genkey -name $EC_CURVE | openssl ec $SYMMETRIC_CIPHER -passout pass:$password -out $KEY_PATH/contractLeaf.key
else
    openssl genpkey -algorithm $EC_CURVE $SYMMETRIC_CIPHER -pass pass:$password -out $KEY_PATH/contractLeaf.key
fi

# Create a CSR
openssl req -new -key $KEY_PATH/contractLeaf.key -passin pass:$password -config configs/contractLeafCert.cnf -out $CSR_PATH/contractLeaf.csr
echo "$HOST CSR generation is done."

DEST=/venv/lib/python3.10/site-packages/iso15118/shared/pki/
ssh -o 'StrictHostKeyChecking no' root@10.1.2.107 "cd $DEST;mkdir -p $CERT_PATH;mkdir -p $CSR_PATH;mkdir -p $KEY_PATH"
scp $CSR_PATH/contractLeaf.csr root@10.1.2.107:$DEST$CSR_PATH
echo "$HOST CSR is sent to the $MASTER."

# Create an X.509 certificate 
ssh root@10.1.2.107 "cd $DEST;openssl x509 -req -in $CSR_PATH/contractLeaf.csr -extfile configs/contractLeafCert.cnf -extensions ext -CA $CERT_PATH/moSubCA2Cert.pem -CAkey $KEY_PATH/moSubCA2.key -passin pass:$password -set_serial 12356 -out $CERT_PATH/contractLeafCert.pem -days $VALIDITY_CONTRACT_LEAF_CERT"
echo "$HOST certificate generation and signing is finished."
ssh root@10.1.2.107 "cd $DEST;rm $CSR_PATH/contractLeaf.csr"
echo "$HOST CSR is deleted from the $MASTER."

ssh root@10.1.2.107 "cd $DEST;scp -o 'StrictHostKeyChecking no' $CERT_PATH/contractLeafCert.pem root@10.1.2.108:$DEST$CERT_PATH"
echo "$HOST certificate is sent back to the $HOST."
ssh root@10.1.2.107 "cd $DEST;rm $CERT_PATH/contractLeafCert.pem"
echo "$HOST certificate is deleted from the $MASTER."

# Convert the certificates from PEM format to DER format
openssl x509 -inform PEM -in $CERT_PATH/contractLeafCert.pem -outform DER -out $CERT_PATH/contractLeafCert.der
echo "$HOST certificate has been converted and saved in DER format."

# Download moRootCAcert, moSubCA1Cert and moSubCA2Cert
ssh -o 'StrictHostKeyChecking no' root@10.1.2.105 "cd $DEST;scp -o 'StrictHostKeyChecking no' $CERT_PATH/moRootCACert.pem root@10.1.2.108:$DEST$CERT_PATH"
echo "moRootCA certificate is downloaded."
ssh -o 'StrictHostKeyChecking no' root@10.1.2.106 "cd $DEST;scp -o 'StrictHostKeyChecking no' $CERT_PATH/moSubCA1Cert.pem root@10.1.2.108:$DEST$CERT_PATH"
echo "moSubCA1 certificate is downloaded."
ssh -o 'StrictHostKeyChecking no' root@10.1.2.107 "cd $DEST;scp -o 'StrictHostKeyChecking no' $CERT_PATH/moSubCA2Cert.pem root@10.1.2.108:$DEST$CERT_PATH"
echo "moSubCA2 certificate is downloaded."

# Concatenate the contract certificate with the MO Sub-2 and Sub-1 certificates to provide a certificate chain
cat $CERT_PATH/moSubCA2Cert.pem $CERT_PATH/moSubCA1Cert.pem > $CERT_PATH/intermediateMOCACerts.pem
openssl pkcs12 -export -inkey $KEY_PATH/contractLeaf.key -in $CERT_PATH/contractLeafCert.pem -certfile $CERT_PATH/intermediateMOCACerts.pem $SYMMETRIC_CIPHER_PKCS12 -passin pass:$password -passout pass:$password -name contract_leaf_cert -out $CERT_PATH/moCertChain.p12
echo "MO certificate chain is created."

# Download V2GRootCAcert, cpoSubCA1Cert and cpoSubCA2Cert
scp -o 'StrictHostKeyChecking no' root@10.1.2.101:$DEST$CERT_PATH/v2gRootCACert.der $DEST$CERT_PATH
echo "V2GRootCA certificate is downloaded."
scp -o 'StrictHostKeyChecking no' root@10.1.2.102:$DEST$CERT_PATH/cpoSubCA1Cert.der $DEST$CERT_PATH
echo "CPOSubCA1 certificate is downloaded."
scp -o 'StrictHostKeyChecking no' root@10.1.2.103:$DEST$CERT_PATH/cpoSubCA2Cert.der $DEST$CERT_PATH
echo "CPOSubCA2 certificate is downloaded."

# Place all passwords to generated private keys in separate text files.
echo $password > $KEY_PATH/contractLeafPassword.txt
echo "$HOST password saved."

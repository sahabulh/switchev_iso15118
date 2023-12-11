#!/bin/bash

VALIDITY_CPO_SUBCA1_CERT=1460

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

# 0) Create directories if not yet existing
CERT_PATH=$ISO_FOLDER/certs
KEY_PATH=$ISO_FOLDER/private_keys
CSR_PATH=$ISO_FOLDER/csrs
mkdir -p $CERT_PATH
mkdir -p $CSR_PATH
mkdir -p $KEY_PATH

# 2) Create an intermediate CPO sub-CA 1 certificate which is directly signed
#    by the V2GRootCA certificate
# ---------------------------------------------------------------------------
# 2.1) Create a private key (same procedure as for V2GRootCA)
if [ $version == $ISO_2 ];
then
    openssl ecparam -genkey -name $EC_CURVE | openssl ec $SYMMETRIC_CIPHER -passout pass:$password -out $KEY_PATH/cpoSubCA1.key
else
    openssl genpkey -algorithm $EC_CURVE $SYMMETRIC_CIPHER -pass pass:$password -out $KEY_PATH/cpoSubCA1.key
fi
# 2.2) Create a CSR (same procedure as for V2GRootCA)
openssl req -new -key $KEY_PATH/cpoSubCA1.key -passin pass:$password -config configs/cpoSubCA1Cert.cnf -out $CSR_PATH/cpoSubCA1.csr

DEST=/venv/lib/python3.10/site-packages/iso15118/shared/pki/
ssh root@10.1.2.102 "cd $DEST;mkdir -p $CERT_PATH;mkdir -p $CSR_PATH;mkdir -p $KEY_PATH"
scp -o 'StrictHostKeyChecking no' $CSR_PATH/cpoSubCA1.csr root@10.1.2.102:$DEST$CSR_PATH

# 2.3) Create an X.509 certificate (same procedure as for V2GRootCA, but with
#      the difference that we need the ‘-CA’ switch to point to the CA
#      certificate, followed by the ‘-CAkey’ switch that tells OpenSSL where to
#      find the CA’s private key. We need the private key to create the signature
#      and the public key certificate to make sure that the CA’s certificate and
#      private key match.
ssh root@10.1.2.102 "cd $DEST;openssl x509 -req -in $CSR_PATH/cpoSubCA1.csr -extfile configs/cpoSubCA1Cert.cnf -extensions ext -CA $CERT_PATH/v2gRootCACert.pem -CAkey $KEY_PATH/v2gRootCA.key -passin pass:$password -set_serial 12346 -out $CERT_PATH/cpoSubCA1Cert.pem -days $VALIDITY_CPO_SUBCA1_CERT"

ssh root@10.1.2.102 "cd $DEST;scp -o 'StrictHostKeyChecking no' $CERT_PATH/cpoSubCA1Cert.pem root@10.1.2.101:$DEST$CERT_PATH"

# 16) Finally we need to convert the certificates from PEM format to DER format
#     (PEM is the default format, but ISO 15118 only allows DER format)
openssl x509 -inform PEM -in $CERT_PATH/cpoSubCA1Cert.pem -outform DER -out $CERT_PATH/cpoSubCA1Cert.der

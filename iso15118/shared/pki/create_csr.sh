#!/bin/bash

password=12345
ISO_2="iso-2"
ISO_20="iso-20"

usage() {
  echo "
  Usage: "$0" -e EMAID -v VERSION{iso-2,iso-20}
  Options:
   [-e or --emaid]	EMAID of the EV
   [-v or --version]	ISO version to run the script for: 'iso-2' refers to ISO 15118-2,
			whereas 'iso-20' refers to ISO 15118-20
  "
  exit 0;
}

validate_option() {
    # Check if the version provided is valid, if not it returns
    if [ "$1" != $ISO_2 ] && [ "$1" != $ISO_20 ]; then
        echo "The version provided is invalid."
        usage
    fi
}

if [ -z $1 ]; then echo "No options were provided"; usage; fi

while [ -n "$1" ]; do
    case "$1" in
	-e|--emaid)
	    EMAID=$2
	    ;;
        -v|--version)
            validate_option $2
            version=$2
            shift  # params with args need an extra shift
            ;;
    esac
    shift
done

if [ $version == $ISO_2 ];
then
    ISO_FOLDER=iso15118_2
    KEY_ALG=prime256v1
    SYM_CIP=-aes-128-cbc
    SHA=-sha256
else
    ISO_FOLDER=iso15118_20
    KEY_ALG=secp521r1
    SYM_CIP=-aes-256-cbc
    SHA=-sha512
fi

KEY_PATH=key_vault/$ISO_FOLDER
CSR_PATH=$ISO_FOLDER/csrs
CERT_PATH=$ISO_FOLDER/certs

echo $version
echo $ISO_2
echo $ISO_20
echo $KEY_PATH
echo $CSR_PATH
echo $CERT_PATH

mkdir -p $CERT_PATH
mkdir -p $CSR_PATH
mkdir -p $KEY_PATH

openssl ecparam -genkey -name $KEY_ALG | openssl ec $SYM_CIP -passout pass:$password -out $KEY_PATH/$EMAID.key
openssl req -new -key $KEY_PATH/$EMAID.key -passin pass:$password -config configs/$ISO_FOLDER/contractLeafCert.cnf $SHA -out $CSR_PATH/$EMAID.csr -subj "/C=US/O=Sandia/OU=EV Department/CN=$EMAID/DC=MO"

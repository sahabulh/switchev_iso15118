#!/bin/bash

# - a to-be-updated contract certificate
VALIDITY_CPS_LEAF_CERT=90


# 15) Create a provisioning service certificate, which is the leaf certificate
#     belonging to the certificate provisioning service chain (used for contract
#     certificate installation)
openssl ecparam -genkey -name $EC_CURVE | openssl ec $SYMMETRIC_CIPHER -passout pass:$password -out $KEY_PATH/cpsLeaf.key
openssl req -new -key $KEY_PATH/cpsLeaf.key -passin pass:$password -config configs/cpsLeafCert.cnf -out $CSR_PATH/cpsLeafCert.csr
openssl x509 -req -in $CSR_PATH/cpsLeafCert.csr -extfile configs/cpsLeafCert.cnf -extensions ext -CA $CERT_PATH/cpsSubCA2Cert.pem -CAkey $KEY_PATH/cpsSubCA2.key -passin pass:$password -set_serial 12359 -days $VALIDITY_CPS_LEAF_CERT -out $CERT_PATH/cpsLeafCert.pem
cat $CERT_PATH/cpsSubCA2Cert.pem $CERT_PATH/cpsSubCA1Cert.pem > $CERT_PATH/intermediateCPSCACerts.pem
openssl pkcs12 -export -inkey $KEY_PATH/cpsLeaf.key -in $CERT_PATH/cpsLeafCert.pem -certfile $CERT_PATH/intermediateCPSCACerts.pem $SYMMETRIC_CIPHER_PKCS12 -passin pass:$password -passout pass:$password -name cps_leaf_cert -out $CERT_PATH/cpsCertChain.p12


# 16) Finally we need to convert the certificates from PEM format to DER format
#     (PEM is the default format, but ISO 15118 only allows DER format)
openssl x509 -inform PEM -in $CERT_PATH/cpsLeafCert.pem 	-outform DER -out $CERT_PATH/cpsLeafCert.der
# Since the intermediate certificates need to be in PEM format when putting them
# in a PKCS12 container and the resulting PKCS12 file is a binary format, it
# might be sufficient. Otherwise, I have currently no idea how to covert the
# intermediate certificates in DER without running into problems when creating
# the PKCS12 container.


# 18) Place all passwords to generated private keys in separate text files.
#     In this script, even though we use a single password for all certificates,
#     certificates from a different source could have been generated with a different
#     passphrase/passkey/password altogether. Leave them empty if no password is required.
echo $password > $KEY_PATH/cpsLeafPassword.txt
echo $password > $KEY_PATH/moSubCA2LeafPassword.txt

#!/bin/bash

# - a to-be-updated contract certificate
VALIDITY_OEM_LEAF_CERT=1460
VALIDITY_OEM_SUBCA2_CERT=1460
VALIDITY_OEM_SUBCA1_CERT=1460
VALIDITY_CPS_LEAF_CERT=90
VALIDITY_CPS_SUBCA2_CERT=730
VALIDITY_CPS_SUBCA1_CERT=1460

# 6) Create an intermediate OEM sub-CA certificate, which is directly signed by
#    the OEMRootCA certificate (validity is up to the OEM)
openssl ecparam -genkey -name $EC_CURVE | openssl ec $SYMMETRIC_CIPHER -passout pass:$password -out $KEY_PATH/oemSubCA1.key
openssl req -new -key $KEY_PATH/oemSubCA1.key -passin pass:$password -config configs/oemSubCA1Cert.cnf -out $CSR_PATH/oemSubCA1.csr
openssl x509 -req -in $CSR_PATH/oemSubCA1.csr -extfile configs/oemSubCA1Cert.cnf -extensions ext -CA $CERT_PATH/oemRootCACert.pem -CAkey $KEY_PATH/oemRootCA.key -passin pass:$password -set_serial 12350 -days $VALIDITY_OEM_SUBCA1_CERT -out $CERT_PATH/oemSubCA1Cert.pem


# 7) Create a second intermediate OEM sub-CA certificate, which is directly
#    signed by the OEMSubCA1 certificate (validity is up to the OEM)
openssl ecparam -genkey -name $EC_CURVE | openssl ec $SYMMETRIC_CIPHER -passout pass:$password -out $KEY_PATH/oemSubCA2.key
openssl req -new -key $KEY_PATH/oemSubCA2.key -passin pass:$password -config configs/oemSubCA2Cert.cnf -out $CSR_PATH/oemSubCA2.csr
openssl x509 -req -in $CSR_PATH/oemSubCA2.csr -extfile configs/oemSubCA2Cert.cnf -extensions ext -CA $CERT_PATH/oemSubCA1Cert.pem -CAkey $KEY_PATH/oemSubCA1.key -passin pass:$password -set_serial 12351 -days $VALIDITY_OEM_SUBCA2_CERT -out $CERT_PATH/oemSubCA2Cert.pem


# 8) Create an OEM provisioning certificate, which is the leaf certificate
#    belonging to the OEM certificate chain (used for contract certificate
#    installation)
openssl ecparam -genkey -name $EC_CURVE | openssl ec $SYMMETRIC_CIPHER -passout pass:$password -out $KEY_PATH/oemLeaf.key
openssl req -new -key $KEY_PATH/oemLeaf.key -passin pass:$password -config configs/oemLeafCert.cnf -out $CSR_PATH/oemLeafCert.csr
openssl x509 -req -in $CSR_PATH/oemLeafCert.csr -extfile configs/oemLeafCert.cnf -extensions ext -CA $CERT_PATH/oemSubCA2Cert.pem -CAkey $KEY_PATH/oemSubCA2.key -passin pass:$password -set_serial 12352 -days $VALIDITY_OEM_LEAF_CERT -out $CERT_PATH/oemLeafCert.pem


# 13) Create an intermediate provisioning service sub-CA certificate, which is
#     directly signed by the V2GRootCA
openssl ecparam -genkey -name $EC_CURVE | openssl ec $SYMMETRIC_CIPHER -passout pass:$password -out $KEY_PATH/cpsSubCA1.key
openssl req -new -key $KEY_PATH/cpsSubCA1.key -passin pass:$password -config configs/cpsSubCA1Cert.cnf -out $CSR_PATH/cpsSubCA1.csr
openssl x509 -req -in $CSR_PATH/cpsSubCA1.csr -extfile configs/cpsSubCA1Cert.cnf -extensions ext -CA $CERT_PATH/v2gRootCACert.pem -CAkey $KEY_PATH/v2gRootCA.key -passin pass:$password -set_serial 12357 -days $VALIDITY_CPS_SUBCA1_CERT -out $CERT_PATH/cpsSubCA1Cert.pem


# 14) Create a second intermediate provisioning sub-CA certificate, which is
#     directly signed by the CPSSubCA1
openssl ecparam -genkey -name $EC_CURVE | openssl ec $SYMMETRIC_CIPHER -passout pass:$password -out $KEY_PATH/cpsSubCA2.key
openssl req -new -key $KEY_PATH/cpsSubCA2.key -passin pass:$password -config configs/cpsSubCA2Cert.cnf -out $CSR_PATH/cpsSubCA2.csr
openssl x509 -req -in $CSR_PATH/cpsSubCA2.csr -extfile configs/cpsSubCA2Cert.cnf -extensions ext -CA $CERT_PATH/cpsSubCA1Cert.pem -CAkey $KEY_PATH/cpsSubCA1.key -passin pass:$password -set_serial 12358 -days $VALIDITY_CPS_SUBCA2_CERT -out $CERT_PATH/cpsSubCA2Cert.pem


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
openssl x509 -inform PEM -in $CERT_PATH/cpsSubCA1Cert.pem -outform DER -out $CERT_PATH/cpsSubCA1Cert.der
openssl x509 -inform PEM -in $CERT_PATH/cpsSubCA2Cert.pem -outform DER -out $CERT_PATH/cpsSubCA2Cert.der
openssl x509 -inform PEM -in $CERT_PATH/cpsLeafCert.pem 	-outform DER -out $CERT_PATH/cpsLeafCert.der
openssl x509 -inform PEM -in $CERT_PATH/oemRootCACert.pem -outform DER -out $CERT_PATH/oemRootCACert.der
openssl x509 -inform PEM -in $CERT_PATH/oemSubCA1Cert.pem -outform DER -out $CERT_PATH/oemSubCA1Cert.der
openssl x509 -inform PEM -in $CERT_PATH/oemSubCA2Cert.pem -outform DER -out $CERT_PATH/oemSubCA2Cert.der
openssl x509 -inform PEM -in $CERT_PATH/oemLeafCert.pem   -outform DER -out $CERT_PATH/oemLeafCert.der
# Since the intermediate certificates need to be in PEM format when putting them
# in a PKCS12 container and the resulting PKCS12 file is a binary format, it
# might be sufficient. Otherwise, I have currently no idea how to covert the
# intermediate certificates in DER without running into problems when creating
# the PKCS12 container.


# 18) Place all passwords to generated private keys in separate text files.
#     In this script, even though we use a single password for all certificates,
#     certificates from a different source could have been generated with a different
#     passphrase/passkey/password altogether. Leave them empty if no password is required.
echo $password > $KEY_PATH/oemLeafPassword.txt
echo $password > $KEY_PATH/cpsLeafPassword.txt
echo $password > $KEY_PATH/moSubCA2LeafPassword.txt

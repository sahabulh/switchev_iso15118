password=12345
KEY_PATH=private_keys
CSR_PATH=csrs
KEY_ALG=prime256v1
SYM_CIP=-aes-128-cbc
SHA=-sha256

usage() {
  echo "
  Usage: "$0" -e EMAID

  Options:
   [-e or --emaid] EMAID of the EV
  "
  exit 0;
}

if [ -z $1 ]; then
    echo "No EMAID is provided."
    usage
else
while [ -n "$1" ]; do
    case "$1" in
	-e|--emaid)
	    EMAID=$2
	    ;;
    esac
    shift
done
fi

openssl ecparam -genkey -name $KEY_ALG | openssl ec $SYM_CIP -passout pass:$password -out $KEY_PATH/$EMAID.key
openssl req -new -key $KEY_PATH/$EMAID.key -passin pass:$password -config configs/contractLeafCert.cnf $SHA -out $CSR_PATH/$EMAID.csr -subj "/C=US/O=Sandia/OU=EV Department/CN=$EMAID/DC=MO"

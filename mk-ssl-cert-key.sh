#!/bin/bash
set -e

SCRIPTDIR=$(cd $(dirname "$0") && pwd -P)

: ${DOMAIN:?must be set the DNS domain root (ex: example.com)}
: ${KEY_BITS:=4096}
: ${DAYS:=1825}

# Generate CA Certificate
openssl req -new -x509 -nodes -sha256 -newkey rsa:${KEY_BITS} -days ${DAYS} -keyout ${DOMAIN}.ca.key.pkcs8 -out ${DOMAIN}.ca.crt -config <( cat << EOF
[ req ]
prompt = no
distinguished_name = dn

[ dn ]
C  = KR
O = Private
CN = Autogenerated CA
EOF
)

# Generate Private key with CA Certificate key
openssl rsa -in ${DOMAIN}.ca.key.pkcs8 -out ${DOMAIN}.ca.key
## Check private key
openssl rsa -in ${DOMAIN}.ca.key -check

# Generate CSR
openssl req -nodes -sha256 -newkey rsa:${KEY_BITS} -days ${DAYS} -keyout ${DOMAIN}.key -out ${DOMAIN}.csr -config <( cat << EOF
[ req ]
prompt = no
distinguished_name = dn
req_extensions = v3_req

[ dn ]
C  = KR
O = Private
CN = *.${DOMAIN}

[ v3_req ]
subjectAltName = DNS:*.${DOMAIN}, DNS:*.apps.${DOMAIN}, DNS:*.sys.${DOMAIN}
EOF
)
## Check CSR
openssl req -text -noout -verify -in ${DOMAIN}.csr

# Generate a Self-Signed Certificate from an Private Key and CSR
openssl x509 -req -in ${DOMAIN}.csr -CA ${DOMAIN}.ca.crt -CAkey ${DOMAIN}.ca.key.pkcs8 -CAcreateserial -out ${DOMAIN}.host.crt -days ${DAYS} -sha256 -extfile <( cat << EOF
basicConstraints = CA:FALSE
subjectAltName = DNS:*.${DOMAIN}, DNS:*.apps.${DOMAIN}, DNS:*.sys.${DOMAIN}
subjectKeyIdentifier = hash
EOF
)

# Merge Self-Signed Certificate with CA certificate
cat ${DOMAIN}.host.crt ${DOMAIN}.ca.crt > ${DOMAIN}.crt
## Check 
openssl x509 -text -noout -in ${DOMAIN}.crt

rm -rf ${DOMAIN}.host.crt ${DOMAIN}.csr ${DOMAIN}.ca.crt ${DOMAIN}.ca.key ${DOMAIN}.ca.key.pkcs8 *.srl
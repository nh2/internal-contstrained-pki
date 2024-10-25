#! /usr/bin/env bash

set -eu -o pipefail

# Creates an .internal X.509 PKI whose root CA is safe to include
# system-wide for others.
#
# This makes it easy to add TLS to local networks or VPNs.
#
# Safe because it uses `nameConstraints` so it can only be used
# for `.mydomain.internal` domains and it cannot be used
# to MITM other DNS names (but potentially IP addresses, see
# https://github.com/caddyserver/caddy/issues/5759#issuecomment-1690700681).
#
# If you set
#     BASE_DOMAIN="mydomain.internal"
# the script will generate a wildcard certificate:
#     mydomain.internal
#     *.mydomain.internal
#
# The generated keys will be unencrypted (no passphrase)
# to allow the script to run without prompts.
# Generate them directly onto at-rest encrypted storage.
# If you want passphrases, add e.g. `-aes256` to the
# `openssl genrsa` invocations.
#
# Requires `openssl` on `$PATH`.
#
# Based on:
#     https://systemoverlord.com/2020/06/14/private-ca-with-x-509-name-constraints.html


BASE_DOMAIN="${1:-"mydomain.internal"}" # change `mydomain` to a name of your choice
echo $BASE_DOMAIN

VALIDITY_DAYS="3650" # 10 years

mkdir -p certs-and-keys/
cd certs-and-keys/


# Create CA
if [ -f "ca-${BASE_DOMAIN}.key.pem" ]; then
  echo >&2 "Will not overwrite existing: "ca-${BASE_DOMAIN}.key.pem""
else

  # Create CA key

  set -x
  openssl genrsa -out "ca-${BASE_DOMAIN}.key.pem" 4096
  openssl req -new -key "ca-${BASE_DOMAIN}.key.pem" -batch -out "ca-${BASE_DOMAIN}.csr" -utf8 -subj '/O=Internal'
  { set +x; } 2> /dev/null


  # Create CA cert

  cat <<EOF >caext-${BASE_DOMAIN}.ini
basicConstraints     = critical, CA:TRUE
keyUsage             = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
nameConstraints      = critical, permitted;DNS:${BASE_DOMAIN} , permitted;DNS:.${BASE_DOMAIN}
EOF
  set -x
  openssl x509 -req -sha256 -days "$VALIDITY_DAYS" -in "ca-${BASE_DOMAIN}.csr" -signkey "ca-${BASE_DOMAIN}.key.pem" -extfile "caext-${BASE_DOMAIN}.ini" -out "ca-${BASE_DOMAIN}.crt"
  { set +x; } 2> /dev/null

  # Create serial counter
  echo 1000 > ""ca-${BASE_DOMAIN}.srl""
fi



# Create certificate for the desired domains.

# *.${BASE_DOMAIN}
if [ -f wildcard.${BASE_DOMAIN}.key.pem ]; then
  echo >&2 "Will not overwrite existing: wildcard.${BASE_DOMAIN}.key.pem"
else
  set -x
  openssl genrsa -out wildcard.${BASE_DOMAIN}.key.pem 2048
  openssl req -new -key wildcard.${BASE_DOMAIN}.key.pem -batch -out "wildcard.${BASE_DOMAIN}.csr" -utf8 -subj "/CN=*.${BASE_DOMAIN}"
  { set +x; } 2> /dev/null

  cat <<'EOF' >"certext-wildcard.${BASE_DOMAIN}.ini"
basicConstraints        = critical, CA:FALSE
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always
nsCertType              = server
authorityKeyIdentifier  = keyid, issuer:always
keyUsage                = critical, digitalSignature, keyEncipherment
extendedKeyUsage        = serverAuth
subjectAltName          = ${ENV::CERT_SAN}
EOF
  set -x
  CERT_SAN="DNS:${BASE_DOMAIN},DNS:*.${BASE_DOMAIN}" openssl x509 -req -sha256 -days "$VALIDITY_DAYS" -in "wildcard.${BASE_DOMAIN}.csr" -CAkey "ca-${BASE_DOMAIN}.key.pem" -CA "ca-${BASE_DOMAIN}.crt" -CAserial "ca-${BASE_DOMAIN}.srl" -out "wildcard.${BASE_DOMAIN}.crt" -extfile "certext-wildcard.${BASE_DOMAIN}.ini"
  { set +x; } 2> /dev/null
fi

# Check
set -x
openssl verify -CAfile "ca-${BASE_DOMAIN}.crt" "wildcard.${BASE_DOMAIN}.crt"
{ set +x; } 2> /dev/null

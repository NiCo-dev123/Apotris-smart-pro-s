#!/bin/bash

cd "${0%/*}"
cd ../Resources/
# Bundled OpenSSL does not use the macOS Keychain trust store.
export SSL_CERT_FILE="$PWD/assets/ssl/cacert.pem"
../MacOS/Apotris

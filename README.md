## Just want simple TLS for your [`.internal`](https://en.wikipedia.org/wiki/.internal) network?

Run

```sh
./create-internal-constrained-pki.sh mydomain.internal
```

It creates a root CA certificate that your users (colleagues/friends/family) can **_safely_** add to their devices' trust store because it uses X.509 [`Name Constraints`](https://netflixtechblog.com/bettertls-c9915cd255c0) to provably restrict it to the chosen domain.

The CA cannot be used to [MitM](https://en.wikipedia.org/wiki/Man-in-the-middle_attack) all traffic.

Result:

```
certs-and-keys/
    ca-mydomain.internal.crt           <- root CA certificate to give to your users
                                          to _safely_ add to their devices' trust store

    wildcard.mydomain.internal.crt     <- certificate and key to use for hosting services
    wildcard.mydomain.internal.key.pem    under mydomain.internal and *.mydomain.internal
```


## Verification

Your users can run

```sh
openssl x509 -noout -text -in ca-mydomain.internal.crt
```

to verify which domains the root CA allows; it should show:

```
            X509v3 Name Constraints: critical
                Permitted:
                  DNS:mydomain.internal
                  DNS:.mydomain.internal
```

## Important

* Read the code of `create-internal-constrained-pki.sh` to see if it suites your goals:
  * Default `VALIDITY_DAYS="3650"`
  * **No passphrases:** The generated keys will be unencrypted (no passphrase) to allow the script to run without prompts. **Generate them directly onto at-rest encrypted storage.** If you want passphrases instead, add e.g. `-aes256` to the `openssl genrsa` invocations.


## Literature

* Security StackExchange: [Can I restrict a Certification Authority to signing certain domains only?](https://security.stackexchange.com/questions/31376/can-i-restrict-a-certification-authority-to-signing-certain-domains-only/130674#130674)

* https://systemoverlord.com/2020/06/14/private-ca-with-x-509-name-constraints.html
  with `openssl` instructions

* https://utcc.utoronto.ca/~cks/space/blog/tech/TLSInternalCANameConstraints

* https://utcc.utoronto.ca/~cks/space/blog/tech/TLSInternalCANameConstraintsII?showcomments

* [`step-ca`](https://smallstep.com/docs/step-ca/) is easier than `openssl`, but apparently can use `Name Constraints` only in intermediate certificates:
  https://smallstep.com/docs/step-ca/templates/#adding-name-constraints
  So this does not meet our goal.
  https://smallstep.com/docs/step-ca/#limitations also says:

  > Its root CA is always offline; a single-tier PKI is not supported

  Further, see https://github.com/caddyserver/caddy/issues/5759

* Support in clients was originally bad, where many would allow to bypass the Name Constraints:
  https://news.ycombinator.com/item?id=37537689

* The spec does not even require that Name Constraint be enforced on Root CAs, only on intermediates:
  https://issues.chromium.org/issues/40685439

  That creates the same problem as above, not meeting the goal.

  However, Chrome now [supports it](https://issues.chromium.org/issues/40685439) properly, and OpenSSL and Firefox already did before.

  https://bettertls.com tracks which implementations support it how well.
  Good write-up: https://netflixtechblog.com/bettertls-c9915cd255c0

* Important point from https://github.com/caddyserver/caddy/issues/5759#issuecomment-1690700681:

  > People using name constraints should know what they exactly mean, as some cases are not obvious. For example, **adding just `permittedDNSDomains` as above does not exclude creating domains with IP addresses or any other type of SAN**. Name constraints are defined in [RFC5280#4.2.1.10](https://datatracker.ietf.org/doc/html/rfc5280#section-4.2.1.10)

  * See also:
    https://github.com/FiloSottile/mkcert/pull/309/commits/922158ed6856077c8b07478d67e0a7a930b90510#r1805672121

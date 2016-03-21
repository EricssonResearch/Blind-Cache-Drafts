---
title: Caching Secure HTTP Content using Blind Caches
abbrev: Blind Cache
docname: draft-eriksson-http-bc
date: 2016
category: std
ipr: trust200902

stand_alone: yes
pi: [toc, sortrefs, symrefs, docmapping]

author:
 -
    ins: G. Eriksson
    name: Göran AP Eriksson
    org: Ericsson
    email: goran.ap.eriksson@ericsson.com
 -
    ins: C. Holmberg
    name: Christer Holmberg
    org: Ericsson
    email: christer.holmberg@ericsson.com
 -
    ins: M. Thomson
    name: Martin Thomson
    org: Mozilla
    email: martin.thomson@gmail.com


normative:
  RFC2119:
  RFC2818:
  RFC7230:
  RFC7234:
  RFC7540:
  SCD:
    title: An Architecture for Secure Content Delegation using HTTP
    author:
      - ins: G. Ericsson
      - ins: C. Holmberg
      - ins: M. Thomson
    date: 2016-02-07
    target: draft-eriksson-http-scd.html
  I-D.ietf-httpbis-encryption-encoding:
  I-D.thomson-http-mice:

informative:
  RFC7231:
  I-D.reschke-http-oob-encoding:

--- abstract

A mechanism is described whereby a server can use client-selected shared cache.


--- middle

# Shared Caching for HTTPS

Shared caches allow an HTTP server to offload the responsibility for delivering
certain content.  Content in the shared cache can be accessed efficiently by
multiple clients, saving the origin server from having to serve those requests
and ensuring that clients receive responses to cached requests more quickly.

Proxy caching is the most common configuration for shared caching.  A proxy
cache is either explicitly configured by a client, discovered as a result of
being automatically configured, or interposed automatically by an on-path
network entity (this latter case being called a transparent proxy).

HTTPS [RFC2818] prevents the use of proxies by creating an authenticated
end-to-end connection to the origin server or its gateway that is authenticated.
This provides a critical protection against man-in-the-middle attacks, but it
also prevents the proxy from acting as a shared cache.

Thus, clients use the CONNECT pseudo-method (Section 4.3.6 of [RFC7231]) with any
explicitly configured proxies to create an end-to-end tunnel and will refuse to
send a query for an `https` URI to a proxy.

This document describes a method for conditionally delegating the hosting of
secure content to the same server.  This delegation allows a client to send a
request for an `https` resource via a proxy rather than insisting on an
end-to-end TLS connection.  This enables shared caching for a limited set of
`https` resources, as selected by the server.


## Notational Conventions

The words "MUST", "MUST NOT", "SHOULD", and "MAY" are used in this document.
It's not shouting; when they are capitalized, they have the special meaning
defined in [RFC2119].

This document uses the term "proxy cache" to refer to a proxy [RFC7230] that
operates an HTTP cache [RFC7234].


# Same-Host Secure Content Delegation

The secure content delegation mechanism defined in [SCD] is used to create a
separate resource that contains encrypted and integrity protected content.

A client that signals a willingness to support this feature can be provided an
response with an out-of-band encoding [I-D.reschke-http-oob-encoding] that
identifies this resource.  The client can then make a request for that content
to a proxy cache rather than directly to the origin server.

In this document, the origin server is able to act in the role of the CDN in
[SCD].  However, all of the considerations that apply to having a third party
host content apply to the proxy cache.  Thus, integrity and confidentiality
protections against the proxy cache are the primary consideration.


## Enabling Proxy Use

It is not sufficient to couple the acceptance and use of out-of-band content
encoding with the use of a proxy.  Without an additional signal, a resource
using secure content delegation to a CDN [SCD] could trigger a request via a
proxy.

The security properties of delegation via a CDN and via a caching proxy are
similar only to the extent that a third party is involved.  However, it might be
the case that the CDN has a stronger relationship with the origin server and
additional constraints on its actions, such as contractual limitations.  Such
constraints might make delegation to the CDN acceptable to the origin server.  A
caching proxy might not be considered acceptable.

Therefore, a clear signal from the origin server is needed to allow the client
to identify which resources are safe to retrieve from a proxy-cache.  A `proxy`
extension to the JSON format defined in [I-D.reschke-http-oob-encoding] is added
that signals to the client that the out-of-band content MAY be retrieved by
making a request to a proxy.

The `proxy` attribute is a boolean value.  In its absence, the value is assumed
to be false.  If present and set to true, a client can send the request for the
out-of-band content to a proxy instead of the identified server.

Clients MUST NOT send a request via a proxy if the message containing the
out-of-band content encoding does not include header fields for message
integrity and encryption, such as the M-I header field [I-D.thomson-http-mice]
or the Crypto-Key header field [I-D.ietf-httpbis-encryption-encoding].  Absence
of these header fields indicate an error on the part of the origin server, since
integrity and confidentiality protection are mandatory.


## Proxy Identification and Authentication

This mechanism does not work with a transparent caching proxy.  Since the
request is made over end-to-end HTTPS in the absence of a proxy, the feature
will not be used unless the proxy is known to the client.

A proxy cache MUST therefore be expressly configured or discovered.  This
produces a name and possibly a port number for the proxy.  The proxy MUST be
contacted using HTTPS [RFC2818] and authenticated using the configured or
discovered domain name.


# Performance Optimizations

As noted in [SCD], the secondary request required by out-of-band content
encoding imposes a performance penalty.  This can be mitigated by priming
clients with information about the location and disposition of resources prior
to the client making a request.  A resource map described in [SCD] might be
provided to clients to eliminate the latency involved in making requests of the
origin server for resources that might be cached.


## Proxy Cache Priming

A client that makes a request of an origin server via an unprimed proxy cache will
suffer additional latency as a consequence of the cache having to make a request
to the origin server.

The following options are possible:

* Clients can speculatively make requests to a proxy cache based on information
  it learns from a resource map.  To avoid a potential waste of resources as a
  result of receiving complete responses, these might either be limited to HEAD
  requests; HTTP/2 [RFC7540] flow control might be used to allow only limited
  information to be sent.

* The origin server might provide the proxy cache with "prefetch" link relations
  in responses to requests for secondary resources.  These link relations might
  identify other resources that the proxy might retrieve speculatively.  This
  does not improve the latency of the initial request, but could improve
  subsequent requests.


# Security Considerations {#security}

All the considerations of [SCD] apply.  In particular, content that is
distributed with the assistance of a proxy cache MUST include integrity and
confidentiality protection.  That means that the M-I header field
[I-D.thomson-http-mice] and the Crypto-Key header field
[I-D.ietf-httpbis-encryption-encoding] or equivalent information MUST be present
in responses that include an out-of-band content encoding.

Clients that receive a response without the information necessary to ensure
integrity and confidentiality protection against a proxy cache MUST NOT make a
request to a proxy to retrieve that response.  Clients could treat such a
response as failed, make the request directly to the origin server, or retry a
request without the out-of-band token in the Accept-Encoding header field (for
idempotent methods only).

# IANA Considerations {#iana}

This document has no IANA actions.

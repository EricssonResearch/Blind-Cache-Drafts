---
title: Caching Secure HTTP Content using Blind Caches
abbrev: Blind Cache
docname: draft-thomson-http-bc
date: 2016
category: std
ipr: trust200902

stand_alone: yes
pi: [toc, sortrefs, symrefs, docmapping]

author:
 -
    ins: M. Thomson
    name: Martin Thomson
    org: Mozilla
    email: martin.thomson@gmail.com
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
  I-D.ietf-httpbis-encryption-encoding:
  I-D.thomson-http-mice:

informative:
  RFC7231:
  I-D.reschke-http-oob-encoding:
  HINTS:
    title: "Resource Hints"
    author:
      - ins: I. Grigorik
    date: 2015-05-27
    seriesinfo: W3C TR

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
being automatically configured.  Network operators or other on-path network
entities can also interpose a transparent caching proxy, which removes the
requirement for discovery or configuration.

HTTPS [RFC2818] prevents the use of proxies by creating an authenticated
end-to-end connection to the origin server or its gateway that is authenticated.
This provides a critical protection against man-in-the-middle attacks, but it
also prevents the proxy from acting as a shared cache.

Clients do not direct queries for `https` URIs to proxies.  Clients configured
with a proxy use the CONNECT pseudo-method (Section 4.3.6 of [RFC7231]) with any
explicitly configured or discovered proxies to create an end-to-end tunnel.
Transparent proxies are unable to intercept connections that are protected with
TLS.

This document describes a method that enables shared caching for a limited set
of `https` resources, as selected by the server.  The server conditionally
delegates the hosting of secure content to itself.  This delegation includes a
marker that signals permission for a client to send a request for an `https`
resource via a proxy rather than insisting on an end-to-end TLS connection.


## Notational Conventions

The words "MUST", "MUST NOT", "SHOULD", and "MAY" are used in this document.
It's not shouting; when they are capitalized, they have the special meaning
defined in [RFC2119].

This document uses the term "proxy cache" to refer to a proxy [RFC7230] that
operates an HTTP cache [RFC7234].


# Same-Host Secure Content Delegation

The secure content delegation mechanism defined in [SCD] is used to create a
separate resource that contains encrypted and integrity protected content.
To enable caching, the primary and secondary servers can be the same server.

A client that signals a willingness to support delegation is provided with a
response that uses out-of-band encoding [I-D.reschke-http-oob-encoding].  The
out-of-band encoding identifies a secondary resource and includes a signal that
indicates that the client is permitted to use a proxy.  The client is then able
to request the secondary resource from a proxy cache rather than directly to the
origin server.

In this document, the origin server is able to act in the role of the secondary
server in [SCD].  However, all of the considerations that apply to having a
secondary server host content apply instead to the proxy cache.  Thus, integrity
and confidentiality protections against the proxy cache are the primary
consideration.


## Signaling Presence of a Proxy

Without a clear signal from the client that a caching proxy is present, an
origin server is unable to send a response with out-of-band encoding.  A value
of `out-of-band` in the Accept-Encoding header field might only indicate
willingness to use the secure content delegation mechanism.

The BC header field indicates that a client is connected to a proxy cache that
it is willing to use for out-of-band requests.  The value of the BC header field
is a simple boolean, represented as a "0" or "1".  A value that is present and
set to "1" indicates that a proxy cache is present and available for use.  This
header field can be used even if the current request was not routed via a proxy.

~~~ abnf
   BC = "0" / "1"
~~~

Issue:

: What signal do we need from the proxy cache that it supports this mode of
  operation?  Can we expect that a proxy cache will happily accept a request for
  an HTTPS URL?

This signal purposefully does not identify the proxy.  This avoids exposing
information about the proxy to clients that are using private proxies.  It also
avoids origin servers making judgments about the character of proxies.


## Enabling Proxy Use

It is not sufficient to couple the acceptance and use of out-of-band content
encoding with the use of a proxy.  Without an additional signal, a resource
using secure content delegation to a secondary server [SCD] could trigger a
request via a proxy.

The security properties of delegation via a secondary server and via a caching
proxy are similar only to the extent that a third party is involved.  However,
it might be the case that a secondary server has a stronger relationship with
the primary server and additional constraints on its actions, such as
contractual limitations.  Such constraints might make it feasible to delegate to
a secondary server selected by the primary server.  A caching proxy might not be
considered acceptable in the same way.

Therefore, a clear signal from the primary server is needed to allow the client
to identify which resources are safe to retrieve from a proxy-cache.  A `proxy`
extension to the JSON format defined in [I-D.reschke-http-oob-encoding] is added
that signals to the client that the out-of-band content MAY be retrieved by
making a request to a proxy.

The `proxy` member is a boolean value that exists at the top level of the
out-of-band JSON document.  In its absence, the value is assumed to be false.
If present and set to true, a client can send the request for the out-of-band
content to a proxy instead of the identified server.

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
  requests; alternatively, HTTP/2 [RFC7540] flow control might be used to allow
  only limited information to be sent.

* The origin server might provide the proxy cache with "prefetch" link relations
  [HINTS] in responses to requests for secondary resources.  These link
  relations might identify other resources that the proxy might retrieve
  speculatively.  This does not improve the latency of the initial request, but
  could improve subsequent requests.


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

This document has no IANA actions.  It should.

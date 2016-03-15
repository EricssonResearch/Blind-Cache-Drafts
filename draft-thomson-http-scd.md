---
title: An Architecture for Secure Content Delegation using HTTP
abbrev: Secure Content Delegation
docname: draft-eriksson-http-scd
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
  I-D.reschke-http-oob-encoding:
  I-D.thomson-http-mice:
  RFC7230:
  RFC7540:

informative:
  RFC2104:
  RFC2818:
  RFC6454:
  CSP:
    title: Content Security Policy Level 2
    author:
      - ins: M. West
      - ins: A. Barth
      - ins: D. Veditz
    date: 2015-08-29
    target: https://w3c.github.io/webappsec-csp/2/
  SRI:
    title: Subresource Integrity
    author:
      - ins: D. Akhawe
      - ins: F. Braun
      - ins: F. Marier
      - ins: J. Weinberger
    date: 2015-11-13
    target: https://w3c.github.io/webappsec-subresource-integrity
  CORS:
    title: Cross-Origin Resource Sharing
    author:
      - ins: A. van Kesteren
    date: 2014-01-16
    target: https://www.w3.org/TR/cors/
  I-D.thomson-http-content-signature:
  I-D.ietf-httpbis-encryption-encoding:

--- abstract

An architecture is described for content distribution via third-party content
distribution networks with reduced privileges.  This architecture allows an
origin server to delegate the responsibility for delivery of the payload of an
HTTP response to a third party.  That party is unable to modify this content.
The content is encrypted, which in some cases will prevent the third party from
learning about the content.


--- middle

# Content Distribution Security

The distribution of content on the web at scale is necessarily highly
distributed.  Large amounts of content needs large numbers of servers.  And
distributing those servers closer to clients has a significant, positive impact
on performance.

This has led to large networks of content distribution servers, in some cases
operated by web sites, but often run by third parties in service to sites that
don't have the resources to operate a network at very large scales.  A content
distribution network (CDN) aims to dramatically improve the performance of
content delivery by moving content closer to clients and by offloading the
delivery responsibility to servers that are highly optimized for that task.

A major drawback of existing solutions for content distribution is that an
origin is required to yield control over their content to the CDN.  A CDN is
able to see and modify content that they distribute.  In some cases, expediency
dictates that the CDN be given control over the entire origin.

There are few technical mechanisms in place to limit the capabilities of a CDN.
Mechanisms like content security policy [CSP] and sub-resource integrity [SRI]
can be used to prevent modification of resources in some contexts, but these
mechanisms are limited in what they can protect and they can impose certain
operational costs.  For the most part, operators of origin servers either limit
the content that is served using the CDN or rely on non-technical measures such
as contracts and courts to proscribe bad behavior.


## Secure Content Delegation

This document describes how an origin server might securely delegate the
responsibility for serving content to a CDN.  The solution comprises three basic
components:

* A delegation component allows an origin server to delegate specific resources
  to another server.

* Integrity attributes ensure that the content cannot be modified by the
  delegated server.

* Confidentiality protection limits the ability of the delegated server to learn
  what the content holds.

Note that the guarantees provided by confidentiality protection are not strong,
see {{confidentiality}} for details.

In addition to these basic components, a fourth mechanism provides a client with
the ability to learn resource metadata from the origin prior to making a request
for specific resources.  This can dramatically improve performance where a
client needs to acquire multiple delegated resources.

No new mechanisms are described in this document; the application of several
existing and separately-proposed protocol mechanisms to this problem is
described.  An origin server can use these mechanisms to take advantage of
content distribution networks where concerns about security might have otherwise
prevented their use.  This might be for content that was previously considered
too sensitive for third-party distribution, or for a CDN provider that might not
otherwise be used.


## Notational Conventions

The words "MUST", "MUST NOT", "SHOULD", and "MAY" are used in this document.
It's not shouting; when they are capitalized, they have the special meaning
defined in [RFC2119].

This document uses the terms client, CDN, and origin server.  These terms refer
to the three roles played in this architecture.  Note that "origin server" as
used in this document encompasses both origin servers and gateways as defined in
[RFC7230].


# Out-of-Band Content Encoding

The out-of-band content encoding [I-D.reschke-http-oob-encoding] provides the
basis for delegation of content distribution.  A request is made to the origin
server, but in place of the complete response only response header fields and an
out-of-band content encoding is provided.  The out-of-band content encoding
directs the client to retrieve content from another resource.

~~~ drawing
   Client           Cache/CDN           Server
     |                  |                 |
     | Request          |                 |
     +----------------------------------->|
     |                  |                 |
     |                  Response + OOB CE |
     |<-----------------------------------+
     |                  |                 |
     |GET               |                 |
     +----------------->|                 |
     |                  |                 |
     |              200 |                 |
     |<-----------------+                 |
     |                  |                 |
~~~
{: #ex-oob title="Using Out-of-Band Content Encoding"}

Out-of-band content encoding behaves much like a redirect.  In fact, a redirect
was considered as part of the early design, but rejected because without
defining a new set of 3xx status codes it would change the effective origin
[RFC6454] of the resource.  Furthermore, the content encoding specifically
preserves header fields sent by the origin server, rejecting any unauthenticated
header fields that might be provided by the CDN.


## Performance Trade-Off

An additional request is necessary to retrieve content.  This has a negative
impact on latency.  However, if the CDN server is positioned close to the
client, there are several potential benefits:

Fewer bit-miles:

: Content hosted in the CDN that is nearby can be served to those clients
  without having to traverse a long network path.

Better server resource allocation:

: Using a dedicated content delivery server reduces the load on the origin
  server, allowing it more capacity for serving other requests.

Lower time to last byte:

: For some resources, the proximity of the CDN might also permit greater
  network throughput.  Increased bandwidth can counteract the added latency cost
  of the extra requests, and potentially reduce the time needed to retrieve the
  entire resource.

Better throughput:

: If a CDN is closer to a client, more bandwidth might be available for delivery
  of content when compared with the link between client and origin server.

The problems of providing integrity protection for content delivered in this
fashion is discussed in {{integrity}}; confidentiality protection and its
limitations is described in {{confidentiality}}; and reducing the latency impact
of making multiple requests for each resource is described in {{map}}.


## Confidentiality of Resource Identity {#urls}

The URL used to acquire a resource from a CDN can be unrelated to the URL of the
resource that refers to its contents.  This allows an origin server to hide the
relationship between content in a CDN and the original resources that is served
by that content.

Any entity SHOULD be unable to determine the URL of the original resource based
on the URL of the CDN resource alone.  This can be achieved by having randomized
URLs for CDN resources and maintaining a mapping table, or by using a fixed
mapping function with a secret input such as HMAC [RFC2104].

Without other information, this would prevent the CDN from learning which
resources are requested from the origin server by observing the requests that it
serves for out-of-band content.  Note that in some cases, information about the
resource is readily obtainable by the CDN cache, see {{confidentiality}}, an
unpredictable mapping ensures that other protection mechanisms can be effective
if possible.


# Content Integrity {#integrity}

Ensuring that content is not modified by the CDN is crucial to ensuring that
content cannot be improperly modified.  Information that is acquired from the
CDN is not integrity protected and therefore MUST NOT be used without being
authenticated.

Several options are available for authenticating content provided by the CDN:

* A cryptographic hash over the content sent in the initial response could be
  compared against a hash of the content delivered by the CDN.  This is the
  basic design of [SRI].

* A digital signature could cover the content stored by the CDN.  A design that
  uses this approach is described in [I-D.thomson-http-content-signature].

A progressive integrity mechanism like the one described in
[I-D.thomson-http-mice] is perhaps the most flexible approach.  It allows for
progressive consumption of content without losing integrity protection.  This
supports both hash- and signature-based integrity protection for out-of-band
content:

* A response from the origin server could include an M-I header field with an
  integrity proof, allowing the content to be delivered out-of-band without any
  additional header fields.

* A response from the origin server could include a Crypto-Key header field with
  a signature public key.  The out-of-band response could then include a M-I
  header field with the signature in addition to the content.


# Content Confidentiality {#confidentiality}

Confidentiality protection for content is provided by applying an encryption
content encoding [I-D.ietf-httpbis-encryption-encoding] to content before that
content is provided to a CDN.

Much of the value provided by a CDN derives from its ability to deliver the same
content to multiple nearby clients.  The more clients that can be delivered the
same resource, the greater the efficiency gains.  As a result, resources that
are provided to many or all clients are the ones that benefit most from caching.

This means that unless a resource has access control mechanisms that would
prevent the CDN from accessing a resource, the confidentiality protections
provided by encrypting content is limited.  A CDN need only independently
request resources from the origin server in order to learn everything about the
content it is serving, including the mapping of origin server URLs to CDN
resource URLs.  For instance, employing a web crawler on a web site might reveal
the identity of numerous resources and the location of the any out-of-band
content for those resources.

Nonetheless, confidentiality protection MUST be used to prevent cross-origin
theft of confidential data (see {{sec-cors}}).


# Resource Map {#map}

Learning about header fields and out-of-band cache locations for resources in
advance of needing to make requests to those resources allows a client to avoid
making requests to the origin server.  This can greatly improve the performance
of applications that make multiple requests of the same server, such as web
browsing or video streaming.

Without defining any new additional protocol mechanisms, HTTP/2 server push
[RFC7540] can be used to provide requests, responses and the out-of-band content
encoding information describing resources.  Since no actual content is included,
this requires relatively little data to describe a number of resources.  Once
this information is available, the client no longer needs to contact the origin
server to acquire the described resources.

This approach has some signficant deployment drawbacks, so explicit data formats
for carrying this data might be defined.

Note:

: We need a separate draft on these alternative methods.


# Error Handling

Error handling for clients is described in [I-D.reschke-http-oob-encoding].

For idempotent requests, a second request might be made to the origin server.
This request would omit any indication of support for out-of-band content coding
from the Accept-Encoding header field, plus a link relation indicating the
secondary resource and the reason for failure.

An origin server can use this information to inform choices about whether to use
content delegation.

Non-idempotent requests cannot be safely retried.  Therefore, clients cannot
retry a a request and provide information about errors to the origin server.
For this reason, origin servers SHOULD NOT delegate content for non-idempotent
methods.


# Security Considerations {#security}

This document describes a framework whereby content might be distributed to a
CDN, without losing integrity with respect to the content that is distributed.

This design relies on integrity and confidentiality for the request and response
made to the origin server.  These requests MUST be made using HTTP over TLS
(HTTPS) [RFC2818] only.  Though there is a lesser requirement for
confidentiality, requests made to the CDN cache MUST also be secured using HTTPS.


## Confidentiality Protection Limitations

Content that requires only integrity protection can be safely distributed by a
third-party using this design.  Entities that make a decision about
confidentiality for others have often been shown to be incorrect in the past.
An incorrect conclusion have serious consequences.  Thus the choice of whether
confidentiality protection is needed is quite important.

Some confidentiality protection against the CDN is provided, but that is limited
to content that is not otherwise accessible to that server (see
{{confidentiality}}).  Only content that has access controls on the origin
server that prevent access by the CDN can retain confidentiality protection.

Content with different access control policies MUST use different keying
material for encryption.  This prevents a client with access to one resource
from acquiring keys that can be used for resources they are not authorized to
access.

Clients that wish to retain control over the confidentiality of responses can
omit the out-of-band label from the Accept-Encoding header field on requests,
thereby indicating that a direct response is necessary.


## Cross-Origin Access {#sec-cors}

The content delegation creates the possibility that an origin server could adopt
remotely hosted content.  On the web, this is normally limited by Cross-Origin
Resource Sharing [CORS], which requires that a client first request permission
to make a resource accessible to another origin.

This document describes a method whereby content hosted on a remote server can
be made accessible to another origin.  The content of the out-of-band resource is
written into the content of a response from the origin.  All an origin needs to
make this happen is knowledge of the identity of the out-of-band resource, something
that might be difficult based on the guidance in {{urls}}, but not infeasible.
A client requests this content using any ambient authority available to it (such
as HTTP authentication header fields and cookies).

The simplest option for reducing the ability to steal content in this fashion is
to require that the origin demonstrate that it knows the content of the
resource.  Unfortunately, this demonstration is difficult without imposing
significant performance penalties, so we require a lesser assurance: that the
origin knows how to decrypt the content.

This makes content confidentiality {{confidentiality}} mandatory and limits the
resources that can be stolen by an origin to those that are already encrypted.
Most importantly, only resources for which the origin knows the encryption key
can be stolen.

For this protection to be effective, origins MUST use different encryption keys
for resources with different sets of authorized recipients.  Otherwise, an
attacker might learn the encryption key for one resource then use that to
decrypt a resource that it is not authorized to read.

Resources that rely on signature-based integrity protection are made only
marginally more difficult to steal, since the origin needs to learn the signing
public key.  However, this is not expected to be difficult, since
confidentiality protection for public keys.  Resources that rely on hash-based
integrity protection require that the origin learn the hash of the resource.


## Traffic Analysis

Using a CDN reveals a great deal of information to the CDN about resources even
if confidentiality protection is effective.  The size of responses and the
pattern of requests for resources can reveal information about their contents.
When used carefully, padding as described in
[I-D.ietf-httpbis-encryption-encoding] can obscure the length of responses and
reduce the information that the CDN is able to learn.

A random or unpredictable mapping from the primary resource URL on the origin to
the URL of the content is necessary, see {{urls}}.

Length hiding for header fields on responses the origin server might be more
important when an out-of-band encoding is used, since the body of the response
becomes less variable.

Making requests for content to multiple different servers can improve the amount
of content length information available to network observers.  HTTP/2
multiplexing might have otherwise reduced the exposure of length information,
but using out-of-band content encoding could expose lengths for those resources
that can be distributed by a CDN.  Note that this is not fundamentally worse
than HTTP/1.1 in the absence of pipelining.  Padding in HTTP/2 or encrypted
content encoding can be used to further obscure lengths.


# IANA Considerations {#iana}

This document has no IANA actions.


--- back

# Acknowledgements

Magnus Westerlund noted the potential for a violation of the cross origin
protections offered in browsers.

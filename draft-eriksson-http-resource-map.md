---
title: HTTP Resource map for out-of-band content delivery
docname: draft-eriksson-http-rmap
date: 2016
category: info
ipr: trust200902

pi: [toc, sortrefs]

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
    ins: Z. Sarker
    name: Zaheduzzaman Sarker
    org: Ericsson
    email: zaheduzzaman.sarker@ericsson.com
 -
    ins: J. Reschke
    name: Julian Reschke
    org: Greenbytes
    email: julian.reschke@greenbytes.de

normative:
  RFC2119:
  I-D.reschke-http-oob-encoding:
  I-D.thomson-http-mice:
  RFC7230:
  RFC7231:
  RFC5988:
  HTTP-SCD:
    title: An Architecture for Secure Content Delegation using HTTP
    author:
      - ins: M. Thomson
      - ins: G. Eriksson
      - ins: C. Holmberg
    target: draft-thomson-http-scd.html
  HTTP-BC:
    title: Caching Secure HTTP Content using Blind Caches
    author:
      - ins: M. Thomson
      - ins: C. Holmberg
      - ins: G. Eriksson
    target:  draft-thomson-http-bc.html
informative:
  RFC6570:
  I-D.ietf-httpbis-encryption-encoding:
  Fetch:
    title: Fetch
    target: https://fetch.spec.whatwg.org
  ServiceWorkers:
    title: Service Workers
    author:
      - ins: A. Russell
      - ins: J. Song
      - ins: J. Archibald
    target: https://www.w3.org/TR/service-workers/
  DASH:
    title: "Information technology -- Dynamic adaptive streaming over HTTP (DASH) -- Part 1: Media presentation description and segment formats"
    author:
      - organization: International Organization for Standardization
    date: 2014-05
    target: http://www.iso.org/iso/home/store/catalogue_ics/catalogue_detail_ics.htm?csnumber=65274
    seriesinfo:
      "ISO/IEC": 23009-1:2014

--- abstract

When the 'out-of-band' content coding ('OOB') is used for delivering a number of resources from an origin server via a secondary server, the additional round trips for OOB responses from the origin server can be a significant nuisance.

In such situations, it is useful for the origin to be able to provide the client with OOB response information for several resources in one go, anticipating future client requests.

This document describes a format for providing the client with the information, called a resource map, and how the resource map could be delivered to a client.

Discussion of this draft takes place on the HTTP working group mailing list (ietf-http-wg@w3.org), which is archived at <https://lists.w3.org/Archives/Public/ietf-http-wg/>.

--- middle

# Introduction

The mechanisms outlined in '[HTTP-SCD]' and '[HTTP-BC]' use the 'out-of-band' content coding ('OOB') mechanism '[I-D.reschke-http-oob-encoding]' to delegate the delivery
of resources from an origin server to a client via a secondary server.

In some situations, a origin server might want to delegate the delivery of response payload for a set of resources, for instance video segments, or a set of images or parts of a large file.

In one approach the client sends individual requests for each of the resources to the origin server and the origin server provides the OOB content coding response information for the requested resources as individual responses. This approach adds a minimum of one extra RTT (round trip time) for each resource, before the client can send the GET request to the desired secondary server.

In another approach, to counter the extra RTT required, the origin server can provide OOB content coding information, OOB responses, for the subsequent requests in advance to a client, anticipating the need.
The bundle of OOB mapping information from a primary server to a client for a set of resources is called a "resource map".

# Notational Conventions

 The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
 "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in [RFC2119].

 This document reuses terminology used in the base HTTP
 specifications, namely Section 2 of [RFC7230] and Section 3 of
 [RFC7231].

# The Resource Map

## Overview

The primary server creates a resource map containing information about how a set of resources on the origin server maps to a set of resource locations on one or multiple secondary servers.

Henceforth, the information in a resource map is described as attributes.

A resource map will include the attributes outlined in '[I-D.reschke-http-oob-encoding]' as well as additional attributes related to that it concerns multiple resources.

## Basic Attributes

'[I-D.reschke-http-oob-encoding]' describes a set of attributes for a OOB response.  For convenience, an example is given below.

Client request of a resource:

~~~ example
     GET /test HTTP/1.1
     Host: www.example.com
     Accept-Encoding: gzip, out-of-band
~~~

Response:

~~~ example
     HTTP/1.1 200 OK
     Date: Thu, 14 May 2015 18:52:00 GMT
     Content-Type: text/plain
     Cache-Control: max-age=10, public
     Content-Encoding: out-of-band
     Content-Length: 133
     Vary: Accept-Encoding

     {
       "sr": [
         "http://example.net/bae27c36-fa6a-11e4-ae5d-00059a3c7a00",
         "/c/bae27c36-fa6a-11e4-ae5d-00059a3c7a00"
       ]
     }
~~~
The attributes are described in '[I-D.reschke-http-oob-encoding]' but a brief description is provided here for convenience.
Editor's note: A minimal set of attributes is described below. Additional attributes such as fall back location described in [I-D.reschke-http-oob-encoding]
are not included here but described in {{additional-attributes}}.

The 'Resource-Origin' attribute contains the resource URL at the origin.

The 'Resource-Mapped' attribute contains the resource URL on the secondary server.

In addition to location related information, the resource map includes other information required to recompose the HTTP response from the origin server, such as 'content-type', integrity and encryption information, etc. as outlined in '[I-D.reschke-http-oob-encoding]'.

These are described below for convenience:

Content-Type: The content type associated with the resource content.
The value is the same as in the HTTP Content-Type header field value as if the resource was provided directly by the origin to the client.

Content-Encoding: List of content encoding procedures that have been applied by the origin to the resource when delivered via out-of-band.

MI: Information to verify the integrity of the data delivered via a secondary server as defined in [I-D.thomson-http-mice].

Encryption: Value of "Encryption" response header field defined in
[I-D.ietf-httpbis-encryption-encoding].

When using the resource map, the primary server could use a template or formula to optimize the size of the resource map information. For example, using URI templates [RFC6570], and an agreed upon HMAC of the path postfix, it would be possible to specify a mapping for many URIs at once.

~~~ example
originURI = "https://{origin}/images/{postfix}
mappedURI = "https://cache.example.com/{origin}/images/{hmac-of-postfix}
~~~

...would indicate a mapping for any https URI on "origin" below a root path of
"/images/", where the mapped URI would be constructed by concatenating
"https://cache.example.com/", the origin's host name, "/images/", and a base64- or hex-encoded opaque part, computed based on the remainder of the origin URI's path.

## Additional Resource Map Attributes {#additional-attributes}

In addition to the attributes discussed above, an origin server could add other attributes in the resource map extending those in [I-D.reschke-http-oob-encoding].

Max-Age: When expired, secondary server should validate resource status with origin server.

# Resource Map Delivery

There are several ways for how to deliver the resource map from a primary server to a client. Which is most appropriate vary with client type.

The resource map delivery MUST be done using TLS or similar with sufficient means for securing the identity of the origin server and avoid MITM accessing the information.

A resource map might be large. For this reason a client MAY use compression techniques such as 'gzip' to decrease the size.

--- Editors note:
Resource constrained devices could possibly benefit from a CBOR format.

## Basic Method

'[I-D.reschke-http-oob-encoding]' uses a method where the OOB information is returned in the payload of the response from the origin server to a client request for a resource.

This method could also be used to include a resource map for multiple resources inside a single OOB response.

## Using HTTP/2 Push for OOB Responses {#http2-push}

An origin server MAY use HTTP/2 push to deliver OOB responses for subsequent requests from a client.

Each OOB response can include resource map information for one or several resources.

## Resource Map as a Web Resource using Link Header Field

An origin server could provide a resource map location in an OOB response to a request for resource using a Link header field [RFC5988].

~~~~ example
  Link: </map>; rel="http://purl.org/NET/linkrel/resource-map"
~~~~

An origin server can speculatively anticipate a client requesting a resource map and could use HTTP/2 to push the response with the resource map to the client to avoid the extra delay a request for resource map otherwise would incur.

# Security Considerations

All the considerations of [HTTP-SCD] apply.

A resource map can be used to cause the client to request malicious content or perform DoS attacks on a victim secondary server. Clients MUST verify that the identity of server providing the Resource Map.

In the case the resource map is delivered as a separate Web resource, the client MUST verify that the server providing the resource map belong to the same authority as the
primary server.  

The cache should take actions to detect and manage request loops caused by erroneous request from a client.

--- Issue: A resource map attribute that is applicable for a set of resources may open up for mixed attacker-controlled data and secrets... (to be continued).

# IANA Considerations

There are currently no actions for IANA.

--- back

# Example Basic JSON Format for Resource Map

The example below outlines an example of a JSON format containing two resource map entries.

~~~ example   
    [
        {
            "Resource-Origin": "https://origin.com/ex_jsl.js",
            "Resource-Mapped": "https://bc.com/origin.com/564xaG",
            "attributes":
            {
                "Content-Type": "application/javascript",
                "Content-Encoding": "gzip",
                "Max-Age": <Number>,
                "MI": "keyid=...; salt=...",
                "Encryption": <String>,
            }
        },
        {
            "Resource-Origin": "https://origin.com/style.css",
            "Resource-Mapped": "https://bc.com/origin.com/qa5Yr4",
            "attributes":
            {
                "Content-Type": "text/css",
                "Max-Age": <Number>,
                "MI": "keyid=...; salt=...",
                "Encryption": <String>,
            }
        }
    ]
~~~

# Multiple Secondary Server

An origin can provide multiple secondary servers for retrieving a resource or set of resources.

For this reason, the origin server provides the client with a set of alternative secondary servers and an annotation with the intended usage in the resource map.

For example:

'sr: load balance'

A string hinting to the client that requests SHOULD switch to next server in list in case the communication to the secondary server indicates high load, for instance secondary server responds with HTTP/2 GOAWAY message.

'sr: fallback'

A string hinting to client secondary server to try when first secondary not reachable.

This implies there are attributes on server level and individual resource level.

Resource Map for the case when the resources is placed on two different secondary servers.

~~~ example   
{
     "secondary-servers": {
         "server1": {
             "name": "blind cache 1",
             "address": "bc.com",
             "protocol": "https",
             "port": 8083,
             "description": "Some text for debugging"
             }
         },
         "server2": {
             "name": "blind cache 2",
             "address": "bc2.com",
             "protocol": "https",
             "port": 8082,
         }
     },

     "resources": [{
         "resource-origin": "https://origin.com:8080/ex_jsl.js",
         "mapped-path": "/origin.com%3A8080/j39jl3jaac/29jfnf0f",
         "attributes": {
             "Content-Type": "application/javascript",
             "Content-Encoding": "aesgcm-128",
             "MI": ".....",
             "Encryption": "....."
         }
         "mapped": [
             {
                 "server": "server1",
                 "attributes": {
                     "Max-Age": 1800
                 }
             },
             {
                 "server": "server2",
                 "attributes": {
                     "Max-Age": 1800
                 }
             }
         ]
     },
     {
         "resource-origin": "https://origin.com:8080/another_resource.txt",
         "mapped-path": "/origin.com%3A8080/i39jfu2/1njknbs3",
         "attributes": {
             "Content-Type": "text/plain",
             "Content-Encoding": "aesgcm-128",
             "MI": ".....",
             "Encryption": "....."
         }
         "mapped": [
             {
                 "server": "server2",
                 "attributes": {
                     "Max-Age": 1800
                 }
             }
         ]
     }

     ]
}
~~~

# Resource Map in Browser Service Worker

One way to realize secure content delegation based on OOB encoding is the use of [ServiceWorkers]. Service Workers allow extending default browser network stack behavior by sitting between the parent document and the network. Thus, if resource map information is available to the Service Worker JavaScript, it can be used to handle OOB  encoding based response processing. The Service Worker JS can easily be modified and extended to support different needs.

Thus, leveraging the Service Workers mechanism along with [Fetch] and other browser features, a rich and extensible interaction between the web application and origin server is possible. Moreover, it enables signal compression techniques, similar to those used in streaming media manifests [DASH], between the primary server and the client compared to server pushing the OOB encoding
information per resource and does not require the explicit use of HTTP/2 Push, still recognizing the value of HTTP/2 Push for minimizing latency.

The same may be possible to implement in the browser HTTP layer, presumably improving processing and mobile battery consumption characteristics. A mixed approach could also be envisioned, providing a basic, high performance client support with JS API for extensions.

Future prototyping will explore this further.

A summary of results of performance measurements on an experimental solution using Chrome SW is described in {{performance-measurements}}.

# Performance Experiments using the Resource Map Approach {#performance-measurements}

The resource map may contain one or more potential resources that the primary server wants the client to fetch from other delegated server(s). The client then can map the requests for the resources towards the map and sends request to appropriate secondary server and thus can skip sending request to the primary server.

By doing such optimization the client not only can save those extra RTTs but also can save both transport and processing cost for the primary server and on the network.

Experiments with a simple web page with only 7 resources to fetch shows that if the RTT between the client and the primary server 200ms and 300ms in two different tests then average load time with HTTPS (end to end TLS) for that page was 2.073s and 3.066s respectively for 200ms and 300ms RTT legs.
In this case if the '[I-D.reschke-http-oob-encoding]' mechanism is used for all the resources then obviously the total load time will be higher than compared to resources server by the primary server. Later in the same test setup we added a delegation node in the scenario with 40ms RTT between the client and delegate
node and used a resource map to deliver all the cache location of the resources piggybacked on the first request to the secondary server.

As a result 5 out of 7 resources were fetched form the cache node without sending request to the origin server. The page load time decreased by 30.2% and 27.6% for respective 300ms and 200ms RTT between the client and primary server setup. The statistics from HTTP Archive (<http://httparchive.org/>) shows that almost 50% of websites has about 26-100 requests per page for different kinds of resources. If we assume 200ms RTT between the client and
the primary server and 50 requests for a certain page with at most 6 parallel requests and add an extra RTT towards the delegate node before the client actually receives the desired resource, then it is kind of obvious that the gain will be even higher.

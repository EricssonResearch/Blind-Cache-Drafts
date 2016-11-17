# Use cases for Video on HTTP/2


Editor: G Eriksson

Version: PA1


# Introduction

Web applications using HTTP/2 benefit from having different request/responses streams be treated with proper priority. In many (most) cases, the UA resolves this without input from the web applicaiton. For streaming video applications, there is [we boldy postulate] a need to a have a suitable browser API (and other app environments) and underlying User Agent (UA) realization.

This draft concerns a browser API and the UA realization including at least HTTP/2 and QUIC. It describes a set of use cases, outlines a HTTP/2 priority usage and related questions.

The browser API discussed in this context is Fetch(). This does not exclude other API’s are affected but that is out-of-scope.

Note well: The purpose of this document is to use as input to the discussions.
Note well II: HTTP/2 also allows for setting priority on responses on sender side, including on push streams. This will also be discussed to the extent is has relevance for the browser API and UA realization.


# The character of H2 streams

HTTP/2 streams can be short-lived; a single request/response of a small web resource using a fast connection may “live” much less than 100 ms. 

Other streams can be long-lived, for instance subscribing to a notification. There is also the case where a single request can trigger delivery of chunked responses, meaning a number of transport-encoded datagrams carrying the web resource data as a set of chunks, for instance closed or open range requests and chunked reponses. Then there are cases where a request for a resource may trigger the server to push other data as well as sending a response.

The above cases are all asymmetric to their nature, the payload flowing downlink from server to client. There are also cases where HTTP/2 is used to send traffic from client to server, uplink.

In short:

1.	Single request- response
..a.	Short lived
..b.	Long lived
2.	Single request- multiple responses/chunks
3.  Single request- response with push stream
4.	POST requests carrying payload
5.  Future: WebSocket on HTTP/2


# Use cases

## Swapping Tab focus

Assume a minimised mobile browser app with at least two tabs active, ‘a’ and ‘b’, both of which have streams active. User swaps between UA and other apps and when UA in focus, between ‘a’ and ‘b’.

The priorities of the fetches change as a tab is in focus or not.

## Example video pre-fetching to mobile device

Assume web application client fetching video segments for play out. The client may pre-fetch (download) video before user looks at the film but may also during play-out fetch more segments faster, pre-fetch, than what is needed to keep the play-out buffer filled for the immediate need. 

Requests can either be per segment but also for a set of segments in forms of a range request (closed or open), e.g. resulting in chunked response.

It may also be that the video segments pre-fetched to the client cache were not the one’s needed for playout, in which case these need to be fetched from the serving edge server.

From to above the following classes of video streams could be foreseen:

A. Download pre-fetch streams								//Download when video not played
B. Play-out fetch streams when not in device cache			//Or in HTTP layer cache
C. Online pre-fetch streams									//Pre-fetching more than play-out rate

Note: For sake of simplicity, we ignore HTTP/2 push based pre-population of HTTP layer cache for the moment.

During download phase, only streams of ‘A’ type are present. It may however be that more than one fetching process A1, A2, ..., An is ongoing, meaning the client may desire to set and change relative priority(weight) between ‘A1’, ‘A2’…‘An’.

           0
        /  |  \
      A1  A2   A3
      

As the play-out starts, class ‘B’ fetches are triggered. These should initially have a higher priority, e.g. first three segments, to quickly fill the play-out buffer and start the video rendering.  There are two alternatives: 1) canceling ‘A’ and make new ‘C’ requests, 2) or change priority setting of ‘A’, making them dependent on ‘B’. In the following, the latter approach is taken.

  	   B
        /  |  \
    	C1   C2  C3 (previous A)

Note 1: It is essential that the UA and server does not "hog" requests or responses used to fill the play-out buffer when critically low, for instance during initialization. This may require a "no_hog" flag to the UA.

Note 2: Also the server side processing must not how request/responses for streams for filling the buffer. This may require a "no_hog" signal to the server.

When the play-out buffer is a target fill level, the relative weight can change again, giving some of the capacity to the ‘C’ streams.

   	    0
       /    |    \
       B	 C1.....…Cn w = “less than B”

The client may decide to be more or less aggressive in pre-fetching streams and change the priority of C streams, either by stopping some of them, for instance making Cx explicitly dependent on C1, or changing relative priority.

Note 2: Some media players adaptive bitrate algorithm relies (partly) on bandwidth estimates based on RTT of request-response. If the UA is hogging the requests in a manner that significantly impacts this, then the ABR algorithm may either have a larger buffer or risk video QoE to drop.

This realization example shows the need to be able to change the priority of a stream after initialization of the fetch API. Some of the desired behavior can be achieved by proper JS logic, such as stopping Cn>1 requests or pacing them.

The video segments can either be retrieved individually or as a set of chunked responses, either closed, open with or without additional pushed streams. This may impact design to secure how to “keep a handle” to the request after fetch() invocation.


# Ack's

mcmanus, annevk, sarker.

All errors GE's.

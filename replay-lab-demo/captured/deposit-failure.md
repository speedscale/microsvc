### REQUEST ###
```
POST http://localhost:8088/api/transactions/deposit HTTP/1.1
Accept: */*
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJyZXBsYXktbGFiLWRlbW8iLCJ1c2VySWQiOiIxIiwicm9sZXMiOiJVU0VSIiwiZXhwIjoxODkzNDU2MDAwfQ.ZgLN1WSTSnb4u6vvk-z4k8eX7_FIRiK_Uijb0Jkk3Ck
Content-Type: application/json
Host: localhost:8088
User-Agent: curl/8.7.1
```

```
{
  "accountId": 70668,
  "amount": 3.33
}
```

### RESPONSE ###
```
HTTP/1.1 400 Bad Request
Cache-Control: no-cache\, no-store\, max-age=0\, must-revalidate
Date: Thu\, 25 Jun 2026 18:18:27 GMT
Expires: 0
Pragma: no-cache
Vary: Origin, Access-Control-Request-Method, Access-Control-Request-Headers
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-Xss-Protection: 0
```

```
```

### SIGNATURE ###
```
http:host is localhost
http:method is POST
http:queryparams is -NONE-
http:requestBodyJSON is {"accountId":70668,"amount":3.33}
http:url is /api/transactions/deposit
```

### METADATA ###
```
direction: IN
uuid: ac47257d-9df8-4009-adaa-d9c15840767b
ts: 2026-06-25T18:18:27.132643Z
duration: 21ms
tags: captureMode=proxy, k8sAppLabel=my-app, proxyProtocol=tcp:http, proxyType=dual, proxyVersion=v2.5.683, reverseProxyHost=localhost, reverseProxyPort=8088, sequence=13, source=goproxy
```

### INTERNAL - DO NOT MODIFY ###
```
json: {"msgType":"rrpair","resource":"my-app","ts":"2026-06-25T18:18:27.132643Z","l7protocol":"http","duration":21,"tags":{"captureMode":"proxy","k8sAppLabel":"my-app","proxyLocation":"in","proxyProtocol":"tcp:http","proxyType":"dual","proxyVersion":"v2.5.683","reverseProxyHost":"localhost","reverseProxyPort":"8088","sequence":"13","source":"goproxy"},"uuid":"rEclfZ34QAmtqtnBWEB2ew==","direction":"IN","cluster":"undefined","namespace":"undefined","service":"my-app","command":"POST","location":"/api/transactions/deposit","status":"400","http":{"req":{"url":"/api/transactions/deposit","uri":"/api/transactions/deposit","version":"1.1","method":"POST","host":"localhost:8088"},"res":{"statusCode":400,"statusMessage":"400 Bad Request"}},"signature":{"http:host":"bG9jYWxob3N0","http:method":"UE9TVA==","http:queryparams":"","http:requestBodyJSON":"eyJhY2NvdW50SWQiOjcwNjY4LCJhbW91bnQiOjMuMzN9","http:url":"L2FwaS90cmFuc2FjdGlvbnMvZGVwb3NpdA=="},"netinfo":{"id":"5","startTime":"2026-06-25T18:18:27.132578Z","downstream":{"established":"2026-06-25T18:18:27.132042Z","ipAddress":"127.0.0.1","port":64190,"bytesSent":"386"},"upstream":{"established":"2026-06-25T18:18:27.132503Z","ipAddress":"127.0.0.1","port":8088,"hostname":"localhost","bytesSent":"351"}}}
```

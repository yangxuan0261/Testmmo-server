local snax    = require "snax"

svc = snax.self()

svc.post.log("send -> begin call 222")

snax.printf("%s", svc.req.echo("hello, console!"))

svc.post.log("send -> after call")

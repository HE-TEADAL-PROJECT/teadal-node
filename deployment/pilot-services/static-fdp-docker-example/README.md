ERT Docker Compose
------------------

Here's how to start a docker compose env with Nginx and a dummy
content dir as done in the meeting earlier---meeting notes also
included in this dir.

Install Docker Desktop. Then cd into this directory and run

```bash
$ docker compose up -d
```

Now you should be able to access your data products using a URL
in this format:

```
    http://localhost:8000/manrep/<rep id>/<rep type>.csv
```

e.g.

```bash
$ curl -i http://localhost:8000/manrep/2/prod.csv

HTTP/1.1 200 OK
Server: nginx/1.25.4
Date: Mon, 18 Mar 2024 18:07:20 GMT
Content-Type: application/octet-stream
Content-Length: 46
Last-Modified: Mon, 18 Mar 2024 17:57:46 GMT
Connection: keep-alive
ETag: "65f8809a-2e"
Accept-Ranges: bytes

someProdField, someOtherProdField
howzit, bru
```

To stop Docker run (still in this dir)

```bash
$ docker compose down -v
```

If you want to change localhost to something else, just edit your host
file to tie the domain name you'd like to use to `127.0.0.1`. Also you
may want to change the Nginx external port in the Docker Compose file
from `8000` to `80` so you can use URLs like e.g.

```
    http://ert-teadal-node/manrep/2/prod.csv
```

(If you change the port, make sure you have no other service on the
host running on port `80`.)

Have fun!

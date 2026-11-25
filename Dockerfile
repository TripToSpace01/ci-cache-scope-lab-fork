# syntax=docker/dockerfile:1
FROM alpine:3.20
RUN --mount=type=bind,source=src,target=/src cat /src/value.txt > /value.txt
CMD ["cat", "/value.txt"]

FROM dart:stable AS build

WORKDIR /app
COPY pubspec.yaml .
RUN dart pub get

COPY . .
RUN mkdir -p bin && dart compile exe server.dart -o bin/server

FROM debian:bookworm-slim
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/

EXPOSE 8080
CMD ["/app/bin/server"]

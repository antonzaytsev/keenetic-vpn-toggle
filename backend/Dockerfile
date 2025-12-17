FROM ruby:3.4-slim

RUN apt-get update && apt-get install -y \
    build-essential \
    libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

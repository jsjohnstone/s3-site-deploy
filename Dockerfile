FROM python:3.7-alpine
ENV AWSCLI_VERSION='1.16.265'
RUN pip install --quiet --no-cache-dir awscli==${AWSCLI_VERSION}
ADD entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

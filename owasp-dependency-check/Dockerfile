FROM owasp/dependency-check-action:latest

USER root 

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/bin/sh","/entrypoint.sh"]

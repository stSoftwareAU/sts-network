# syntax=docker/dockerfile:1
FROM hashicorp/terraform:light

COPY --chown=nobody:nobody docker-entrypoint.sh .
RUN chmod u+x docker-entrypoint.sh

RUN mkdir /home/IaC

WORKDIR /home/IaC

COPY --chown=nobody:nobody IaC/ .

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["apply"]
# syntax=docker/dockerfile:1
#
# WARNING: Automatically copied from dga-template
#
FROM hashicorp/terraform:light

COPY --chown=nobody:nobody entrypoint.sh .
RUN chmod u+x entrypoint.sh

RUN mkdir /home/IaC

WORKDIR /home/IaC

COPY IaC/ .

RUN chown -R nobody:nobody /home/IaC

ENTRYPOINT ["/entrypoint.sh"]

USER nobody

CMD ["apply"]
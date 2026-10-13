FROM huanheart/ai-service-based-on-http-framework-2

USER root
WORKDIR /root/httpserver_vsersion2

COPY start.sh ./start.sh
RUN chmod +x ./start.sh

EXPOSE 8117
ENTRYPOINT ["/bin/bash", "/root/httpserver_vsersion2/start.sh"]
CMD []

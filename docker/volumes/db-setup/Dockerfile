FROM postgres:15
COPY setup.sh /setup.sh
RUN chmod +x /setup.sh
ENTRYPOINT ["/setup.sh"]

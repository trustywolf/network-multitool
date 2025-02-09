FROM alpine:3.21

EXPOSE 22 80 443 1180 11443

# Install some tools in the container and generate self-signed SSL certificates.
# Packages are listed in alphabetical order, for ease of readability and ease of maintenance.
RUN apk update \
    && apk add apache2-utils bash bind-tools bonding bridge busybox-extras curl \
    dnsmasq dropbear ethtool freeradius git ifupdown-ng iperf iperf3 iproute2 iputils \
    jq lftp mtr mysql-client net-tools netcat-openbsd nginx nmap \
    openntpd openssh-client openssl perl-net-telnet postgresql-client procps-ng \
    rsync socat sudo tcpdump tcptraceroute tshark wget \
    && mkdir /certs /docker \
    && chmod 700 /certs \
    && openssl req \
    -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout /certs/server.key -out /certs/server.crt -subj '/CN=localhost'

RUN wget -q https://github.com/osrg/gobgp/releases/download/v3.34.0/gobgp_3.34.0_linux_amd64.tar.gz \
    && mkdir -p /usr/local/gobgp \
    && tar -C /usr/local/gobgp -xzf gobgp_3.34.0_linux_amd64.tar.gz \
    && cp /usr/local/gobgp/gobgp* /usr/bin/

RUN rm -f /etc/motd && rm -f /root/gobgp_3.34.0_linux_amd64.tar.gz && rm -f /root/.wget-hsts

###
# set a password to SSH into the docker container with
RUN adduser -D -h /home/cisco -s /bin/bash cisco
RUN adduser cisco wheel
RUN sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/g' /etc/sudoers
RUN echo 'cisco:cisco123' | chpasswd
# copy a basic but nicer than standard bashrc for the user
COPY .bashrc /home/cisco/.bashrc
RUN chown cisco:cisco /home/cisco/.bashrc
# Ensure .bashrc is sourced by creating a .bash_profile that sources .bashrc
RUN echo 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi' > /home/cisco/.bash_profile

# Change ownership of the home directory to the user
RUN chown -R cisco:cisco /home/cisco
###

COPY index.html /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/nginx.conf

# copy the bashrc file to the root user's home directory
COPY .bashrc /root/.bashrc
RUN echo 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi' > /root/.bash_profile

COPY entrypoint.sh /docker/entrypoint.sh

# Start nginx in foreground (pass CMD to docker entrypoint.sh):
CMD ["/usr/sbin/nginx", "-g", "daemon off;"]

# Note: If you have not included the "bash" package, then it is "mandatory" to add "/bin/sh"
#         in the ENTNRYPOINT instruction.
#       Otherwise you will get strange errors when you try to run the container.
#       Such as:
#       standard_init_linux.go:219: exec user process caused: no such file or directory

# Run the startup script as ENTRYPOINT, which does few things and then starts nginx.
ENTRYPOINT ["/bin/sh", "/docker/entrypoint.sh"]

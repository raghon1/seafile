Skydns med docker
=================

Modifiser /usr/lib/systemd/system/docker.service, og endre linjen ExecStart til::
    
    ExecStart=/usr/bin/docker -d $OPTIONS --bip=172.17.42.1/16 --dns=172.17.42.1 $DOCKER_STORAGE_OPTIONS


Install skydns og skydoc imager::

    docker pull crosbymichael/skydns
    docker pull crosbymichael/skydock

Sett opp en kontainer for skydns::

    docker run -d -p 172.17.42.1:53:53/udp --name skydns crosbymichael/skydns -nameserver 10.0.80.11:53 -domain docker
    docker run -d -v /var/run/docker.sock:/docker.sock --name skydock crosbymichael/skydock -ttl 30 -environment demo -s /docker.sock -domain docker -name skydns




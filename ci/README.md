# Freedom-Maker CI/CD configuration for [GoCD](https://www.gocd.io/)

### This consists of the following:

- `cruise-config.xml` having GoCD server config which can build images for:
    - amd64
    - i386
    - raspberry
    - raspberry2
    - dreamplug
    - virtualbox-i386
    - virtualbox-amd64
    - qemu-i386
    - qemu-amd64
    - beaglebone
    - cubieboard2
    - cubietruck
    - a20-olinuxino-lime
    - a20-olinuxino-lime2
    - a20-olinuxino-micro
- `Vagrantfile` having the [Vagrant](https://www.vagrantup.com/) configuration which brings up a vanilla Debian amd64 image to act as a GoCD agent.

### Steps to configure and run on a Linux environment:

- Install [Virtualbox](https://www.virtualbox.org/wiki/Downloads).
- Install [Vagrant](https://www.vagrantup.com/downloads.html).
- Install Go [Server](https://www.gocd.io/download/).
- Copy the `cruise-config.xml` to `/etc/go/`.
- Start the Go Server using `sudo systemctl start go-server`.
- Copy the `Vagrantfile` to some location like `/home/<username>`.
- From that directory, start the virtual Debian instance using `vagrant up`. This will bring up a Debian instance called legolas having 2 cores and 2.5GB of RAM.
- ssh into the instance using `vagrant ssh legolas`.
- Update the instance to at least `testing`.
- Install Go [Agent](https://www.gocd.io/download/).
- Edit `/etc/default/go-agent` and set server URL as `GO_SERVER_URL=https://192.168.33.1:8154/go`.
- Install dependencies from [here](https://github.com/freedombox/freedom-maker#install-dependencies).
- Also install the following packages to be able to run unit tests and build debs:
    - git-buildpackage
    - python3-dev
    - python3-cffi
    - python3-setuptools
    - python3-gi
    - python3-augeas
    - libaugeas-dev
- Start the Go Agent using `sudo systemctl start go-agent`.
- Further agents can be added by replicating the `config.vm.define` blocks in the `Vagrantfile` and run `vagrant up <machine_name>`.
- All agents can now be seen in the `Agents` section hopefully picking up the jobs.

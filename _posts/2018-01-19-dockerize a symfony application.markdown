---
layout: post
title:  "Dockerize a Symfony dev environment"
date:   2018-01-19 00:00:00
categories: symfony docker
---

We are going to run the [Symfony demo application](https://github.com/symfony/demo) in a docker container. The main purpose of this guide is to show how you can do this step by step. Afterwards, you must be able to dockerize any PHP application, or actually any application.

If you haven't done it, start by installing [Docker](https://www.docker.com/community-edition). Even if you are not familiar with Docker, this guide is a good starting point to see how it works.

Start by pulling the PHP image, running a container, and executing `bash` inside the PHP container. We can do this using a single command.

````bash
docker run -it php:fpm bash
````
You should get an output similar to
````bash
Unable to find image 'php:fpm' locally
fpm: Pulling from library/php
e7bb522d92ff: Pull complete
...
26b263fd4e72: Pull complete
Digest: sha256:6907a969eed2e673584f5dac8189c8039f35d67ff273ebf99fa539abc32354c0
Status: Downloaded newer image for php:fpm
root@e5b799b92f6e:/var/www/html#
````
To confirm that you have a working PHP environment
````bash
root@e5b799b92f6e:/var/www/html# php -v
PHP 7.2.1 (cli) (built: Jan  8 2018 23:39:24) ( NTS )
Copyright (c) 1997-2017 The PHP Group
Zend Engine v3.2.0, Copyright (c) 1998-2017 Zend Technologies
````

Now we head to [https://github.com/symfony/demo](https://github.com/symfony/demo) to check the installation which is just a single command
````bash
composer create-project symfony/symfony-demo
````

If you try to execute it in the container, you will get an error `bash: composer: command not found`.
And this is exactly the main workflow to dockerize an application. Most of the time you are looking for `XXX not found` like error messages, and fix them. You will not install anything in the created PHP container because all changes you may make there will be lost when you restart the container. Instead you should create a *Dockerfile* so you can recreate (build) and run a container with all the changes already applied.
`exit` the running container. Create a *symfony-demo* directory and create a Dockerfile inside it.

Go to https://getcomposer.org/doc/faqs/how-to-install-composer-programmatically.md and copy the content of the script found there into *install-composer.sh*.

Edit the Dockerfile content
````
FROM php:fpm

COPY install-composer.sh ./install-composer.sh
RUN chmod +x ./install-composer.sh && ./install-composer.sh
RUN mv ./composer.phar /usr/bin/composer
````

Now try to build an image from the Dockerfile with the command `docker build .`  
You should get an error
````bash
./install-composer.sh: 3: ./install-composer.sh: wget: not found
````
Remember, this is what we are looking for. Find errors and fix them. *wget* is missing from the base container. To add it, add to Dockerfile, After the `FROM` command
````bash
RUN apt-get update && apt-get install -y wget
````
Now try to build the container again with the command `docker build . -t symfony-demo`. The build will succeed and finish with
````bash
Successfully built 62d49fa61f8d
Successfully tagged symfony-demo:latest
````
You just created a new docker image with the name *symfony-demo* and tag *latest* (default). To run it, use the command
````bash
docker run -it --name symfony-demo symfony-demo bash
````
You can confirm by running `composer`. If you try to create the project by running
````bash
composer create-project symfony/symfony-demo
````
you will get another error `sh: 1: git: not found`. You guessed it, add **git** to the *apt* list after *wget*. Exist the container, build it and run it again.

The installation should succeed now, you can confirm you have a working Symfony application
````bash
root@2446d0a1e0cb:/var/www/html# cd symfony-demo/
root@2446d0a1e0cb:/var/www/html/symfony-demo# ./bin/console
Symfony 4.0.1 (kernel: src, env: dev, debug: true)
````

If you exist the container now, the cloned project will be lost. To copy it to the host machine, open another terminal and run
````bash
docker cp sad_mclean:/var/www/html/symfony-demo/ .
````

Now you can exit the running container and run it again with mounting the project directory using `-v` and exposing port 8000 using -p
````bash
docker run -it -v $(pwd)/symfony-demo:/var/www/html -p 8000:8000 symfony-demo bash
````
On windows
````bash
docker run -it -v %cd%\symfony-demo:/var/www/html -p 8000:8000 symfony-demo bash
````
In PowerShell
````bash
docker run -it -v ${PWD}/symfony-demo:/var/www/html -p 8000:8000 symfony-demo bash
````

Run the built in web server `bin/console server:run 0.0.0.0:8000`

Visit [http://localhost:8000](http://localhost:8000) you will see the Symfony demo application home page.

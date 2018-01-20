---
layout: post
title:  "Dockerize a Symfony dev environment"
date:   2018-01-19 00:00:00
categories: symfony docker
---

We are going to run the [Symfony demo application](https://github.com/symfony/demo) in a docker container. The main purpose of this guide is to show how you can do it step by step. Afterwards, you must be able to dockerize any PHP application, or actually any application.

If you haven't done it, start by installing [Docker](https://www.docker.com/community-edition). Even if you are not familiar with Docker, this guide is a good starting point to see how it works.

Start by pulling the PHP image, running a container, and executing `bash` inside the PHP container. You can do this with a single command.

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

Now we head to [https://github.com/symfony/demo](https://github.com/symfony/demo) to check the installation documentation which is just a single command
````bash
composer create-project symfony/symfony-demo
````

If you try to execute it in the container, you will get an error `bash: composer: command not found`.
And this is exactly the main workflow to dockerize an application. Most of the time you are looking for `XXX not found` like error messages, and fix them. You will not install anything in the created PHP container because all changes you may make there will be lost when you restart the container. Instead you should create a *Dockerfile* so you can recreate (build) and run a container with all the changes already applied.
`exit` the running container. Create a *symfony-demo* directory and create a Dockerfile inside it.

````
FROM php:fpm

RUN curl https://getcomposer.org/installer | php -- --filename=composer --install-dir=/bin
````

Now try to build an image from the Dockerfile with the command  
````
docker build . -t symfony-demo
````
The build will succeed and finish with an output like
````bash
Successfully built 62d49fa61f8d
Successfully tagged symfony-demo:latest
````
You just created a new docker image with the name *symfony-demo* and tag *latest* (default). To run it, use the command
````bash
docker run -it --name symfony-demo symfony-demo bash
````
If you try to create the project by running
````bash
composer create-project symfony/symfony-demo
````
you will get another error `sh: 1: git: not found`. You guessed it, you need to instal **git**. Edit Dockerfile and add the command
````
RUN apt-get update && apt-get install -y git
````
Exit the container, build it and run it again.

The installation should succeed now, you can confirm you have a working Symfony application
````bash
root@2446d0a1e0cb:/var/www/html# cd symfony-demo/
root@2446d0a1e0cb:/var/www/html/symfony-demo# ./bin/console
Symfony 4.0.1 (kernel: src, env: dev, debug: true)
````

If you exit the container now, the cloned project will be lost. To copy it to the host machine, open another terminal and run
````bash
docker cp symfony-demo:/var/www/html/symfony-demo/ .
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

A development environment is not complete without running the test suite. If you try to run the test suite `/vendor/bin/simple-phpunit` you will get an error

````
Fatal error: Uncaught Exception: simple-phpunit requires the "zip" PHP extension
to be installed and enabled in order to uncompress the downloaded PHPUnit packages
````

To install the zip library add `zlib1g-dev` to the apt install list.  
To install the zip PHP extension, add to Dockerfile the command
````
RUN docker-php-ext-install zip
````
Now the test suite should run successfully. The final Dockerfile looks like

````
FROM php:fpm

RUN curl https://getcomposer.org/installer | php -- --filename=composer --install-dir=/bin
RUN apt-get update && apt-get install -y git zlib1g-dev

RUN docker-php-ext-install zip
````

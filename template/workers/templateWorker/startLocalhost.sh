#!/bin/bash
echo "template worker loaded, waiting for rabbitmq"
while ! nc -z localhost 5672; do sleep 3; done
echo "Rabbitmq loaded"
npm start
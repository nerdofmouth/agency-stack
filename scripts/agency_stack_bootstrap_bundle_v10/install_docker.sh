#!/bin/bash
curl -fsSL https://get.docker.com | sh
usermod -aG docker ${USER}

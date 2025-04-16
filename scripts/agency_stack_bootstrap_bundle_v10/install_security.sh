#!/bin/bash
ufw allow ssh
ufw allow http
ufw allow https
ufw --force enable

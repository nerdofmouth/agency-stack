#!/bin/bash
apt install -y fail2ban
systemctl enable --now fail2ban

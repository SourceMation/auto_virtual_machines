#!/bin/bash -eux

rm -rf /etc/ssh/sshd_config.d/50-redhat.conf

echo "Include /etc/crypto-policies/back-ends/opensshserver.config" >> /etc/ssh/sshd_config
echo "UseDNS no" >> /etc/ssh/sshd_config
echo "ChallengeResponseAuthentication no" >> /etc/ssh/sshd_config
echo "GSSAPIAuthentication no" >> /etc/ssh/sshd_config
echo "SyslogFacility AUTHPRIV" >> /etc/ssh/sshd_config
echo "UsePAM yes" >> /etc/ssh/sshd_config
echo "X11Forwarding yes" >> /etc/ssh/sshd_config

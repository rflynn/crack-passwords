#!/bin/bash

# this script demonstrates how easy it is to crack hashed passwords cheaply and quickly on AWS
# given an ECS commodity GPU instance we can be up and running in a few minutes

# ref: http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using_cluster_computing.html#install-nvidia-driver
# ref: http://rockfishsec.blogspot.com/2015/05/gpu-password-cracking-with-amazon-ec2.html
# ref: http://hashcat.net/oclhashcat/
# ref: https://samsclass.info/123/proj10/p12-hashcat.htm
# ref: https://blog.agilebits.com/2015/03/30/bcrypt-is-great-but-is-password-cracking-infeasible/

# in EC2 [Launch Instance]
# choose Amazon Linux AMI 2015.03 (HVM), SSD Volume Type - ami-1ecae776
# choose GPU instances g2.2xlarge

# login
# ssh -i ~/src/bamx/backend/conf/aws/Bamx-Dev.pem ec2-user@54.175.107.34

# blow away existing graphics drivers (if any)
sudo yum erase nvidia cuda
sudo yum update -y
sudo reboot

# install kernel dev headers needed by drivers
sudo yum groupinstall -y "Development tools"
sudo yum install kernel-devel-`uname -r`

# install the latest and greatest NVIDIA drivers; older ones like -340.xx.run did NOT work
wget http://us.download.nvidia.com/XFree86/Linux-x86_64/346.35/NVIDIA-Linux-x86_64-346.35.run
sudo /bin/bash NVIDIA-Linux-x86_64-346.35.run
sudo reboot

# make sure the previous crap worked
nvidia-smi -q | head

# install cudaHashcat and make sure it works
wget http://hashcat.net/files/cudaHashcat-1.36.7z
wget ftp://rpmfind.net/linux/opensuse/factory/repo/oss/suse/x86_64/p7zip-9.38.1-1.1.x86_64.rpm
sudo yum install -y p7zip-9.38.1-1.1.x86_64.rpm
7z x cudaHashcat-1.36.7z
cd cudaHashcat-1.36
./cudaHashcat64.bin -b | tee benchmark-cudaHashcat-1.36-GP2-GPU.log

# add an example user
sudo adduser crackme
# set a shitty password
echo -e 'password1234\npassword1234' | sudo passwd crackme
# extract SHA512-encrypted shitty password
sudo grep crackme /etc/shadow | cut -d: -f2 > crackme.hash

# download good password dictionary (~14 million entries)
wget http://downloads.skullsecurity.org/passwords/rockyou.txt.bz2
bunzip2 rockyou.txt.bz2
# use cudaHashcat + password dict to crack SHA-512 encrypted shitty password very quickly
time ./cudaHashcat64.bin -m 1800 -w 3 -a 0 crackme.hash rockyou.txt && cat cudaHashcat.pot

<<RESULTS
[ec2-user@ip-172-31-28-132 cudaHashcat-1.36]$ time ./cudaHashcat64.bin -m 1800 -w 3 -a 0 crackme.hash rockyou.txt && cat cudaHashcat.pot
cudaHashcat v1.36 starting...

Device #1: GRID K520, 4095MB, 797Mhz, 8MCU

Hashes: 1 hashes; 1 unique digests, 1 unique salts
Bitmaps: 16 bits, 65536 entries, 0x0000ffff mask, 262144 bytes, 5/13 rotates
Rules: 1
Applicable Optimizers:
* Zero-Byte
* Single-Hash
* Single-Salt
Watchdog: Temperature abort trigger set to 90c
Watchdog: Temperature retain trigger set to 80c
Device #1: Kernel ./kernels/4318/m01800.sm_30.64.ptx
Device #1: Kernel ./kernels/4318/amp_a0_v1.64.ptx

INFO: removed 1 hash found in pot file


Session.Name...: cudaHashcat
Status.........: Cracked
Input.Mode.....: File (rockyou.txt)
Hash.Target....: $6$p45K3h8O$CCCwNLDAuicPtGX2g1LEbpshNC/nV...
Hash.Type......: sha512crypt, SHA512(Unix)
Time.Started...: 0 secs
Speed.GPU.#1...:        0 H/s
Recovered......: 1/1 (100.00%) Digests, 1/1 (100.00%) Salts
Progress.......: 0/0 (100.00%)
Rejected.......: 0/0 (100.00%)
Restore point..: 0/0 (100.00%)
HWMon.GPU.#1...: 99% Util, 41c Temp, N/A Fan

Started: Wed Jun 24 03:34:05 2015
Stopped: Wed Jun 24 03:34:05 2015

real0m0.905s
user0m0.120s
sys0m0.456s
$6$p45K3h8O$CCCwNLDAuicPtGX2g1LEbpshNC/nVneF0UaosdSTOFfLK2  OOlv5fsbG79vVYKsI3RsV3Viu.2/IU6LDXzKDPy.:password1234
RESULTS

# try a better dictionary...
# ref: https://crackstation.net/buy-crackstation-wordlist-password-cracking-dictionary.htm
sudo yum install -y transmission-cli
transmission-cli https://crackstation.net/downloads/crackstation-human-only.txt.gz.torrent
# hit Ctrl-C manually when done...
gunzip ~/Downloads/crackstation-human-only.txt.gz
wc -l ~/Downloads/crackstation-human-only.txt
# 63941069 /home/ec2-user/Downloads/crackstation-human-only.txt
time ./cudaHashcat64.bin -m 1800 -w 3 -a 0 crackme.hash ~/Downloads/crackstation-human-only.txt && cat cudaHashcat.pot

# bcrypt held up very well...


# try CPU-only hashcat...
# ref: hashcat.net
# ref: http://blog.nullmode.com/blog/2015/03/22/36-core-aws-john/

wget https://hashcat.net/files/hashcat-0.50.7z
7z x hashcat-0.50.7z
cd hashcat-0.50
sudo ln -s /usr/lib64/libgmp.so.3 /usr/lib64/libgmp.so.10 # WTF Redhat/AWS
./hashcat-cli64.bin -b | tee benchmark-hashcat-0.50-GP2-CPU.log

